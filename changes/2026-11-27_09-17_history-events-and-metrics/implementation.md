# Implementazione

Regole di progetto valide ovunque: niente commenti, niente ternari inline (anche nei file che sposti: correggi quelli esistenti), testi UI in inglese, sentence case, niente em dash, "…" per i puntini (come in `CleanupView.swift`). File sotto ~350 righe.

## Passo 1, HistoryStore

- Campi nuovi in `HistoryPoint`: `temperatureCelsius: Double?`, `isAway: Bool?`, `pausedApps: Int?`, tutti `let` opzionali. Il `Codable` sintetizzato usa `decodeIfPresent` per le proprietà Optional, quindi un `history.json` vecchio si decodifica senza migrazione. Non scrivere `init(from:)` a mano. Aggiungili in fondo all'`init` con default `nil`.
- Trappola: `Monitor.loadHistory` usa `try?`. Se la decodifica fallisse, lo storico ripartirebbe vuoto e il salvataggio successivo sovrascriverebbe il file. Per questo il test di compatibilità del passo 6 è obbligatorio.
- Firma: `public mutating func record(_ sample: Sample, isAway: Bool = false, pausedApps: Int = 0)`. I default lasciano compilare `TimeSourceTests.historyRoundTrip`.
- `capacity = 10_080`, nuova `public static let retention: TimeInterval = 7 * 86_400`, `trim(olderThan: sample.date - retention)`.
- In `trim` aggiungi una guardia: se `points.first` non è più vecchio del cutoff, esci subito. Con 10 080 punti e un campione ogni 2 s, `removeAll` a ogni campione è lavoro inutile.
- `isAway` e `pausedApps` contano l'ultimo campione del minuto, come già fanno gli altri campi.

## Passo 2, ProtectionMode

- `public enum ProtectionMode: Sendable, Equatable { case on, off, paused(until: Date) }` in `ProtectionSettings.swift`.
- `extension ProtectionSettings { public func mode(at date: Date) -> ProtectionMode }`: `off` se `!isEnabled` (vince sulla pausa), `paused(until:)` se `isPaused(at:)`, altrimenti `on`.
- Serve perché la protezione cambia da quattro punti: `toggleProtection`, `pauseProtection`, `resumeProtectionNow`, il toggle in `ProtectionSettingsView` che scrive direttamente `settings.protection.isEnabled`. In più la pausa scade da sola, senza nessuna chiamata. Confrontare il modo prima e dopo li copre tutti.

## Passo 3, eventi

Contratti condivisi con Monitor, UI ed export:

```swift
public enum HistoryEventKind: String, Codable, CaseIterable, Sendable {
    case alertStarted, alertEnded, notification
    case appPausedByProtection, appResumedByProtection
    case protectionOff, protectionSnoozed, protectionOn
    case manualSuspend, manualResume, manualQuit, manualForceQuit
    case userAway, userBack
}
public enum HistoryEventCategory: String, CaseIterable, Sendable { case alerts, notifications, protection, actions, presence }
public struct HistoryEvent: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID; public let date: Date; public let kind: HistoryEventKind
    public let title: String; public let appName: String?; public let value: String?
    public let detail: String?; public let key: String?; public let notified: Bool?
}
```

- `HistoryEventKind` espone `category` e `title`, l'etichetta breve per export e filtro: "Alert", "Alert cleared", "Notification", "App paused", "App resumed", "Protection off", "Protection paused", "Protection on", "Suspended", "Resumed", "Quit", "Force quit", "Away", "Back". Le cinque voci di protezione, app e stato, vanno nella categoria `protection`. `HistoryEventCategory.title`: "Alerts", "Notifications", "Protection", "Your actions", "Presence". Stesso pattern di `ThermalLevel.title`.
- Trappola sui nomi: `protectionSnoozed` è la protezione in pausa, `appPausedByProtection` è un'app sospesa dalla protezione. Non chiamarli entrambi "paused" nel codice.
- `HistoryEvent.init` con `id: UUID = UUID()` e tutti gli opzionali a `nil`.
- `title` è il testo principale della riga: titolo della regola, titolo della notifica, "Suspended by you", "Resumed by you", "Quit by you", "Force quit by you", "Paused by protection", "Resumed by protection", "Protection turned off", "Protection paused", "Protection turned on", "Protection resumed", "You left the Mac", "You came back". `value` è il valore che ha causato l'evento. `detail` solo per il body delle notifiche. `key` solo per gli avvisi, uguale a `ActiveRule.id`.
- `notified`: `true` se per quell'evento è partita una notifica, `nil` altrimenti. Lo usano `alertStarted`, `appPausedByProtection` e `userBack`.
- `HistoryEventLog: Sendable, Codable` con `public private(set) var events: [HistoryEvent]`, `retention = 7 * 86_400`, `capacity = 5000`.
  - `mutating func append(_ newEvents: [HistoryEvent])`: aggiunge, ordina per data, toglie quelli più vecchi di `retention` rispetto alla data più recente, poi taglia in testa oltre `capacity`.
  - `func events(since: Date) -> [HistoryEvent]` e `func events(in interval: DateInterval) -> [HistoryEvent]`, la seconda per il dettaglio del grafico.
  - `func alertEvents(previous: [ActiveRule], current: [ActiveRule], sample: Sample, notifiedKeys: Set<String>) -> [HistoryEvent]`: confronta per `id`. Per un id nuovo crea un `alertStarted` con il `title` della regola, la `key`, app e valore da `HistoryEventValue.alert(...)` e `notified: true` se la key sta in `notifiedKeys`. Per un id sparito crea un `alertEnded` con lo stesso `title` e la stessa `key`. La sua `appName` va copiata dall'ultimo `alertStarted` con quella `key` nel log, perché il gruppo può non essere più nel campione. Il `value` è "Lasted 12 min", da `previous.since` a `sample.date`. Data degli eventi: `sample.date`.
  - `func presenceEvent(previous: Presence, current: Presence, at: Date, notified: Bool) -> HistoryEvent?`: solo quando `isAway` cambia. `.present` e `.passive` tra loro non generano eventi, perché `passive` conta come presente. Per `userBack` il `value` è "Away 42 min", calcolato dall'ultimo `userAway` nel log, oppure `nil` se non c'è. `notified` vale solo per `userBack`.
  - `func protectionEvent(previous: ProtectionMode, current: ProtectionMode, at now: Date) -> HistoryEvent?`: `nil` se il modo è uguale.
    - `off`: `protectionOff`, "Protection turned off".
    - `paused(until)`: `protectionSnoozed`, "Protection paused", value "Until 15:30" se `until` cade oggi, altrimenti "Until Nov 28, 09:00".
    - `on` partendo da `paused(until)` con `until <= now`: `protectionOn`, "Protection resumed", value "Pause ended", data = `until`. È la scadenza, rilevata solo al campione successivo, e la data vera è quella della scadenza.
    - `on` in ogni altro caso: `protectionOn`, "Protection turned on", data `now`.
    - Calendario e fuso orario come parametri con default `.current`, per i test.
- Trappola: lo stato degli avvisi riparte vuoto a ogni avvio, quindi al primo campione non ci sono falsi "cleared". Gli avvisi attivi alla chiusura restano senza "cleared": è voluto.

## Passo 3, Alert.activeRuleID

- In `RuleDefinition.swift`: `public var activeRuleID: String` su `Alert`, uguale a `"\(ruleID)|\(groupID ?? "system")"`. La chiave combacia con `ActiveRule.id`: `RuleEngine` usa `"\(rule.id)|\(key)"`, con `key` "system" per le regole di sistema e `group.id` per quelle di gruppo, e `activeRules` rimette quella parte in `targetKey`.

## Passo 3, HistoryEventValue

`public enum HistoryEventValue` con funzioni statiche pure:

- `alert(ruleID: String, groupID: String?, sample: Sample) -> (appName: String?, value: String?)`. Se `groupID` c'è, l'app è il `displayName` del gruppo in `sample.groups`. Per le regole di sistema l'app è la causa probabile:
  - top CPU (`sample.topGroups.first`) per `thermal_serious`, `thermal_critical`, `system_cpu`;
  - il gruppo con `footprintBytes` più alto per `memory_warning`, `memory_critical`, `swap_high`;
  - `nil` per gli altri.

  Valori, con gli id verificati in `RuleCatalog.swift`:
  - `thermal_*`: "Thermal serious" (titolo del livello in minuscolo), più ", 92 °C" se c'è la temperatura
  - `memory_*`: "Memory pressure warning"
  - `swap_high`: "Swap 6.2 GB"
  - `system_cpu`: "CPU 380%"
  - `disk_free`: "Free disk 8.1 GB"
  - `process_cpu`, `anomaly_cpu`: CPU del gruppo
  - `memory_leak`, `anomaly_memory`: "Memory 3.2 GB" del gruppo
  - `uptime`, `disk_write` e le regole sconosciute: `nil`
- `group(_ group: ProcessGroup) -> String`: "CPU 182%, memory 3.2 GB".
- `duration(_ seconds: TimeInterval) -> String`: "under 1 min", "12 min", "2 h 5 min".
- Numeri con `String(format:)`, GB = byte / 1_073_741_824 con una cifra decimale. `String(format:)` senza locale usa il punto decimale: serve anche per il CSV.

## Passo 4, serie

```swift
public enum HistoryRange: String, CaseIterable, Identifiable, Sendable { case sixHours, day, week }
public enum HistoryWindow: Hashable, Sendable { case recent(HistoryRange), day(Date) }
public struct HistoryBucket: Sendable, Identifiable, Equatable {
    public var id: Date { start }
    public let start: Date; public let end: Date; public let segment: Int
    public let thermal: ThermalLevel; public let memoryPressure: MemoryPressureLevel
    public let systemCPUPercent: Double; public let temperatureCelsius: Double?
    public let swapUsedBytes: UInt64; public let diskAvailableBytes: Int64
    public let worstGroupName: String?; public let worstGroupCPU: Double
    public let isAway: Bool; public let pausedApps: Int
}
```

- `HistoryRange`: `title` ("6 hours", "24 hours", "7 days"), `duration` (6 h, 24 h, 7 giorni), `bucketSeconds` (60, 300, 1800). Con 10 080 punti e cinque pannelli, Swift Charts senza aggregazione diventa lento: per questo 24 ore e 7 giorni aggregano.
- `HistoryWindow`:
  - `.day(Date)` porta sempre l'inizio del giorno.
  - `interval(now: Date, calendar: Calendar = .current) -> DateInterval`: per `.recent` va da `now - duration` a `now`; per `.day` usa `calendar.dateInterval(of: .day, for:)`. Non usare `+ 86_400`: nei giorni del cambio d'ora l'intervallo è di 23 o 25 ore.
  - `bucketSeconds`: per `.recent` quello del range, per `.day` sempre 60, cioè risoluzione piena.
  - `static func availableDays(now: Date, calendar: Calendar = .current) -> [Date]`: i 7 inizi di giorno da oggi a 6 giorni fa, oggi per primo. Il più vecchio è parziale perché la retention è di 7 × 24 h.
- `enum HistorySeries`:
  - `buckets(points: [HistoryPoint], window: HistoryWindow, now: Date, calendar: Calendar = .current) -> [HistoryBucket]`: prende i punti con `minute` dentro `window.interval(...)`.
    - L'inizio del bucket è l'epoch arrotondato per difetto a `bucketSeconds`, come in `HistoryPoint.minute(of:)`.
    - Aggregazione: massimo per thermal, pressione, CPU, swap e `pausedApps`; massimo anche per la temperatura, ignorando i nil (`nil` se sono tutti nil); minimo per il disco.
    - L'app peggiore è quella del punto con `worstGroupCPU` più alto. `isAway` è vero se almeno un punto lo è.
    - Per i campi nil dei punti vecchi: `isAway` falso, `pausedApps` 0.
  - Segmenti: `segment` cresce quando lo scarto tra l'inizio di due bucket consecutivi supera `2 * bucketSeconds`. Senza segmenti `LineMark` unisce con una retta le ore in cui l'app era chiusa o il Mac dormiva, e il grafico mente.
  - `spans(_ buckets: [HistoryBucket], where predicate: (HistoryBucket) -> Bool) -> [DateInterval]`: unisce bucket consecutivi che soddisfano il predicato e hanno lo stesso segmento. L'intervallo va da `start` del primo a `end` dell'ultimo.
  - `bucket(at date: Date, in buckets: [HistoryBucket]) -> HistoryBucket?`: il bucket con `start <= date < end`, `nil` se la data cade in un buco.

## Passo 5, export

`enum HistoryExport` con `timeZone: TimeZone` come parametro (default `.current`) per avere test deterministici:

- `pointsCSV(_ points: [HistoryPoint], timeZone:) -> String`. Intestazione esatta: `time,thermal,memory_pressure,cpu_percent,temperature_c,swap_gb,disk_free_gb,away,paused_apps,worst_app,worst_app_cpu_percent`. Ora con `ISO8601DateFormatter` (`.withInternetDateTime`, `timeZone` impostata). Livelli col `title`. Opzionali nil come campo vuoto. `away` come `yes`, `no` o vuoto.
- `eventsCSV(_ events: [HistoryEvent], timeZone:) -> String`. Intestazione: `time,event,app,title,value,notified,detail`, con `event` = `kind.title` e `notified` `yes` o vuoto.
- `eventsText(_ events: [HistoryEvent], timeZone:) -> String`: una riga per evento. Formato: `yyyy-MM-dd HH:mm:ss` (`DateFormatter` con locale `en_US_POSIX`), due spazi, `kind.title`, ": ", `title`. Seguono " (app)" e ", value" se presenti, e ", notified" se `notified == true`.
- Escape CSV: se il campo contiene virgola, doppio apice o a capo, va tra doppi apici e i doppi apici interni raddoppiati. I nomi delle app e i body delle notifiche contengono virgole.

## Passo 6, test

Swift Testing come gli altri file (`@Suite`, `@Test`, `#expect`). In `Fixtures.sample` aggiungi `temperature: Double? = nil` e passalo a `temperatureCelsius`. `ActiveRule` ha un init pubblico. Per date e giorni usa un `Calendar` gregoriano con `TimeZone(identifier: "UTC")`.

- HistoryStore:
  - `record` con `isAway: true`, `pausedApps: 2` e temperatura 80 salva i tre campi.
  - Compatibilità: un JSON letterale nel formato vecchio, senza le tre chiavi e con data ISO 8601, va decodificato con lo stesso decoder di `JSONFileStore` (salvalo in un file temporaneo e usa `JSONFileStore.load`). I punti ci sono e i campi nuovi sono nil.
  - Retention: un punto di 6 giorni fa resta, uno di 8 giorni fa viene tolto.
- HistorySeries:
  - `.recent(.sixHours)` dà un bucket per punto ed esclude i punti oltre le 6 ore.
  - `.recent(.week)`: 30 punti in mezz'ora, con CPU da 10 a 40 e disco decrescente, danno un solo bucket. Il bucket ha CPU 40, il disco minimo, l'app del punto con `worstGroupCPU` più alto, e `isAway` vero anche se un solo punto è away.
  - `.day(inizio di ieri)` dà bucket da 60 s, include solo i punti di quel giorno ed esclude quelli di oggi e dell'altro ieri.
  - `availableDays` restituisce 7 date, oggi per prima, ognuna all'inizio del giorno.
  - Un buco di 3 ore con `.recent(.sixHours)` apre un nuovo segmento.
  - `spans` unisce tre bucket away consecutivi in un intervallo e separa due gruppi distinti o in segmenti diversi.
  - `bucket(at:)` trova il bucket che contiene la data e dà nil in un buco.
- HistoryEvent:
  - `[] -> [A]` con la key di A in `notifiedKeys` dà un `alertStarted` con key, titolo, app e valore attesi e `notified == true`. Senza la key, `notified` è nil.
  - `[A] -> []`, con lo start già nel log, dà un `alertEnded` con la stessa app e "Lasted 12 min". Liste uguali non danno eventi.
  - `Alert(ruleID: "process_cpu", groupID: "com.example.app", …).activeRuleID` è uguale all'`id` di un `ActiveRule` con `targetKey` "com.example.app"; per un `Alert` di sistema è uguale con `targetKey` "system".
  - `.absent -> .present`, dopo un `userAway` di 30 minuti prima, dà `userBack` con "Away 30 min". `.present -> .passive` e `.passive -> .present` danno nil.
  - Protezione: `on -> off` dà `protectionOff`. `on -> paused(until)` dà `protectionSnoozed` con "Until …". `paused(until) -> on` con `now` dopo `until` dà "Protection resumed" con data `until`. `paused(until) -> on` con `now` prima di `until` dà "Protection turned on" con data `now`. Modo uguale dà nil.
  - `ProtectionSettings.mode`: con `isEnabled` falso e `pausedUntil` futuro vale `off`.
  - `append` toglie gli eventi più vecchi di 7 giorni e rispetta `capacity`. Round trip JSON del log.
- HistoryExport:
  - intestazione e una riga con `TimeZone(identifier: "UTC")`;
  - temperatura nil come campo vuoto;
  - il nome app `Foo, "Bar"` esportato come `"Foo, ""Bar"""`;
  - formato di una riga di `eventsText`, con e senza ", notified".

## Passo 7, notifiche

- `NotificationPayload`: nuovo campo `public let logsAsEvent: Bool`, parametro dell'init con default `true` in fondo. Le chiamate esistenti, compresa `StorageWatcher`, restano invariate.
- `Notifier`: `public var onSend: (@Sendable (NotificationPayload) -> Void)?`, chiamata alla fine di `send`. Lo hook registra anche le notifiche di `StorageWatcher`, che usa lo stesso `Notifier`: per questo l'hook sta qui e non in un wrapper dentro Monitor. `scheduleWeeklySummary` resta fuori.
- La classe è `@unchecked Sendable`. La callback si imposta una volta sola nell'init di Monitor, prima di qualunque `send`.

## Passo 8, split di Monitor

Solo spostamento. Il codice si sposta così com'è, cambia solo la visibilità.

- `Monitor+Persistence.swift`: `loadIgnoreList`, `persistIgnoreList`, `loadHistory`, `saveHistory`, `saveTrends`, poi `loadEvents` e `saveEvents` (passo 9).
- `Monitor+Notifications.swift`: `deliver(alert:sample:)`, `deliverTrends`, `deliver(notice:)`, `installObservers`.
- Le estensioni in un altro file non vedono i membri `private`: porta a `internal` (senza modificatore) le funzioni spostate e le proprietà che usano (`lastPresenceNoticeAt`, `observers`). Non toccare la logica.

## Passo 9, registrazione in Monitor

Una riga per fatto. Le notifiche legate a un evento passano `logsAsEvent: false` e marcano l'evento con `notified: true`. Tutte le altre restano `true` e diventano righe "Notification" tramite l'hook.

| Notifica | `logsAsEvent` | Dove finisce |
| --- | --- | --- |
| `deliver(alert:)` | `false` | `alertStarted.notified` |
| `deliver(notice:)` `.suspended` | `false` | `appPausedByProtection.notified` |
| "Welcome back" in `handle(signals:)` | `false` | `userBack.notified` |
| `deliver(notice:)` `.returned` | `false` | `userBack.notified` (oggi la policy non la emette) |
| `.presentAdvisory`, `.noCulprit`, `deliverTrends`, `StorageWatcher` | `true` | riga "Notification" |

- `var eventLog = HistoryEventLog()`. Helper privato `record(_ events: [HistoryEvent])`: se l'array è vuoto esce, altrimenti `append` e `saveEvents()` subito. Gli eventi sono rari e un crash dovuto al calore farebbe perdere proprio gli ultimi 10 minuti, che sono quelli interessanti. I punti restano col salvataggio ogni 10 minuti.
- `events.json` in `SupportDirectory`, caricato in `loadHistory`, salvato anche in `shutdown`.
- Init: dopo `loadHistory()`, `notifier.onSend = { [weak self] payload in ... }`. Se `payload.logsAsEvent` è falso non fa niente, altrimenti fa `Task { @MainActor in self?.record([...]) }` con `kind: .notification`, `title: payload.title`, `detail: payload.body`.
- `handle(sample:)`:
  - Salva `let previousRules = activeRules` prima di riassegnarlo.
  - Calcola `notifiedKeys = Set(result.alerts.map(\.activeRuleID))`, poi `record(eventLog.alertEvents(previous:current:sample:notifiedKeys:))`. L'engine emette l'`Alert` nello stesso campione in cui l'`ActiveRule` supera il sustain, quindi le chiavi combaciano. Le notifiche ripetute dopo il cooldown, con l'avviso già attivo, non producono righe, ed è voluto.
  - Sposta `history.record(...)` dopo `evaluateGuard(sample:)` e passa `isAway: presence.isAway`, `pausedApps: guardState.suspended.count`. Prima di `evaluateGuard` il conteggio è quello del campione precedente.
  - Controlla lo stato della protezione (vedi sotto). Serve per la scadenza della pausa, che non passa da nessuna chiamata.
- Stato della protezione: `private var lastProtectionMode: ProtectionMode?` e un helper `checkProtectionMode(now:)`.
  - Se `lastProtectionMode` è nil, lo imposta senza registrare niente, così all'avvio non compare un evento falso. Altrimenti registra `eventLog.protectionEvent(previous:current:at:)` e aggiorna il valore.
  - Va chiamato in `handle(sample:)` e in `applySettings()`. `settings.onChange` scatta anche per il toggle di `ProtectionSettingsView` e per `toggleProtection`, `pauseProtection` e `resumeProtectionNow`, che scrivono `settings.protection`. Non serve aggiungere chiamate dentro quei tre metodi.
- `handle(signals:)`:
  - Dopo il calcolo di `presence`, decide se parte il "Welcome back" (condizione esistente).
  - Registra `eventLog.presenceEvent(previous:current:at: Date(), notified:)` con quel valore.
  - Il confronto esistente `previous == .absent && presence != .absent` equivale a `isAway`: lascialo o riscrivilo con `isAway`, ma senza cambiare la condizione.
- `evaluateGuard`:
  - Salva `let before = guardState.suspended` prima di `guardState = result.state`.
  - Per `.suspend(groupIDs)`: un `appPausedByProtection` per gruppo. L'app e "CPU X%" vengono dal `SuspendedGroup` in `result.state.suspended`, più ", thermal serious". `notified: true` se tra le azioni dello stesso risultato c'è `.notice(.suspended)`: la policy le emette insieme.
  - Per `.resume(groupIDs)`: un `appResumedByProtection` per gruppo, con il nome da `before` e il valore "Paused for 12 min" da `suspendedAt`.
  - Trappola: dopo l'assegnazione i gruppi ripresi non sono più in `guardState`, quindi il nome va preso da `before`.
- `resume(groupID:)` è chiamato sia dalla UI (`SuspendedSectionView`) sia dalla protezione. Sposta il corpo in un `private func resumeGroup(groupID:)`.
  - Il `resume(groupID:)` pubblico registra un `manualResume`, con il nome preso da `guardState.suspended` prima della rimozione, e chiama `resumeGroup`.
  - `evaluateGuard` chiama direttamente `resumeGroup`, altrimenti ogni ripresa automatica comparirebbe anche come azione dell'utente.
- `resumeAllSuspended`: se `guardState.suspended` non è vuoto, prima di svuotarlo registra un solo `manualResume` con `title` "Resumed all paused apps" e `appName` uguale ai nomi uniti da ", ". Spegnendo la protezione dal menu compaiono due righe, "Protection turned off" e questa: è corretto.
- `action(_:on:)`: un evento al momento della richiesta, `appName: group.displayName`, `value: HistoryEventValue.group(group)`. Mappatura: `.suspend` → `manualSuspend`, `.resume` → `manualResume`, `.quit` → `manualQuit`, `.forceQuit` → `manualForceQuit`. Passano di qui anche le azioni dalle notifiche e da `LeftoverSectionView`: va bene.

## Passo 10, UI

- Struttura: `HistoryView` contiene una riga in alto con il menu "Export" a destra e la `TabView` con "Chart" (`chart.xyaxis.line`), "Events" (`list.bullet`), "This week" (`calendar`). `WeeklyReportView` è la vecchia `thisWeek` spostata. Il ternario `change > 0 ? .orange : .green` va sostituito con una funzione che restituisce il colore.
- `HeatGlanceApp`: `defaultSize(width: 760, height: 680)`. In `HistoryView`: `frame(minWidth: 640, minHeight: 560)`.
- `HistoryWindowPicker`: binding a `HistoryWindow`.
  - Un `Picker` segmented con i tre `HistoryRange`, attivo quando la finestra è `.recent`.
  - Accanto un `Menu` "Day" con `HistoryWindow.availableDays`, etichette "Today", "Yesterday" e poi "Mon, Nov 23". La voce scelta passa a `.day`. Se è attivo un giorno, il menu ne mostra il nome.
  - Toccare un segmento torna a `.recent`. Default: `.recent(.day)`.
- `HistoryChartView`: `@State window`, `@State selectedDate: Date?`, `@State buckets: [HistoryBucket]`.
  - Trappola di prestazioni: i bucket non vanno calcolati nel `body`. Con la selezione al passaggio del puntatore il `body` si rivaluta a ogni movimento, e la vista di un giorno ha 1440 bucket su cinque pannelli. Calcolali in `.task(id:)` con un id fatto da `window` e `monitor.history.points.last?.minute`. Da lì ricava anche le fasce away (`isAway`) e paused (`pausedApps > 0`).
  - Quando cambia `window`, azzera `selectedDate`.
  - Ordine dall'alto: picker, legenda delle fasce scritta a mano ("Away" grigio, "Apps paused" arancione), `HistoryDetailView` ad altezza fissa (il layout non salta durante l'hover), poi i pannelli in uno `ScrollView`.
  - Pannelli, nell'ordine:
    - "Thermal and memory pressure": due linee a gradini (`.interpolationMethod(.stepEnd)`), asse y con i titoli dei livelli su 0...3;
    - "Temperature" in °C, solo se almeno un bucket ha la temperatura;
    - "CPU" in %;
    - "Swap" in GB;
    - "Free disk" in GB.
  - Testo vuoto come oggi se non ci sono punti, e "No data for this day" per un giorno senza punti.
- `HistoryMetricChart`, una vista sola per tutti i pannelli: titolo, altezza ~90, una o due serie (nome, colore, `(HistoryBucket) -> Double?`), fasce, dominio x, binding della selezione.
  - `.chartXScale(domain:)` con `window.interval(now:)`, uguale su tutti i pannelli, così restano allineati. Per un giorno passato l'asse copre il giorno intero.
  - Fasce come `RectangleMark(xStart:xEnd:)` senza y, così coprono tutta l'altezza, opacità ~0.15, disegnate prima delle linee.
  - Linee: `LineMark(x:y:series: .value("Segment", "\(nome)-\(bucket.segment)"))` con `.foregroundStyle(colore)` fisso. Non usare `foregroundStyle(by:)`: insieme a `series` mescola colori e legenda.
  - Filtra prima i bucket con valore nil invece di mettere `if let` dentro il builder del Chart.
  - Selezione: `.chartXSelection(value: $selectedDate)` (macOS 14) su ogni pannello con lo stesso binding, più un `RuleMark(x:)` alla data selezionata.
  - Etichette y in larghezza fissa per allineare le aree: `AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in AxisGridLine(); AxisValueLabel { Text(...).frame(width: 44, alignment: .leading) } }`. Se i pannelli restano disallineati, nascondi l'asse y (`.chartYAxis(.hidden)`) e metti il picco nel titolo: i valori esatti li mostra già il dettaglio.
- `HistoryDetailView`:
  - Il bucket è `HistorySeries.bucket(at: selectedDate, ...)`, altrimenti l'ultimo.
  - Ora: "14:32" per i bucket di 1 minuto, "14:30 to 15:00" per gli altri. Il giorno si aggiunge solo nella vista `.recent` e se non è oggi; nella vista di un giorno il giorno è già nel picker.
  - Poi thermal, temperatura, pressione, CPU, swap, disco libero, app peggiore con CPU, e "Away" e "N apps paused" se presenti.
  - Infine fino a 3 eventi da `eventLog.events(in:)` dell'intervallo del bucket.
  - Se la data cade in un buco: "No data for this time".
- `HistoryEventsView`:
  - Un `Picker` con "All" più le categorie e una lista dal più recente, raggruppata per giorno (`Section` con la data).
  - Riga: ora `HH:mm:ss` monospaziata, icona per categoria, `title`, app secondaria, `value` monospaziato secondario, `detail` come `.help`.
  - Se `notified == true`, un'icona `bell` piccola con `.help("Notification sent")`.
  - Stato vuoto: "Events appear here as HeatGlance sees them."
- `HistoryExporter` (enum, AppKit): voci del menu "Copy events as text", "Save events as CSV…", "Save minutes as CSV…". Esporta tutto lo storico (7 giorni), non solo la finestra del grafico.
  - Copia: `NSPasteboard.general.clearContents()` e `setString(_:forType: .string)`.
  - Salva:
    - `NSSavePanel` con `allowedContentTypes = [.commaSeparatedText]` e nome `heatglance-events-yyyy-MM-dd.csv` o `heatglance-minutes-yyyy-MM-dd.csv`;
    - prima del pannello `NSApp.activate()`, perché l'app è `LSUIElement`;
    - scrittura UTF-8 atomica, in caso di errore `NSAlert(error:).runModal()`.
  - L'app non è sandboxed (`ENABLE_APP_SANDBOX: NO` in `project.yml`), quindi non servono entitlement.

## Passo 11, README

Riscrivi `## History` in inglese. Deve coprire:

- le tre schede;
- gli intervalli 6 ore, 24 ore e 7 giorni, con l'aggregazione oltre le 6 ore;
- la scelta di un giorno degli ultimi 7 al minuto;
- le fasce away e paused;
- il dettaglio al passaggio del puntatore;
- cosa finisce nel registro eventi: avvisi con l'indicazione della notifica, app messe in pausa e riprese, stato della protezione, azioni dell'utente, uscita e ritorno, le altre notifiche;
- l'esportazione e la retention di 7 giorni;
- i file `history.json` ed `events.json` nella cartella di supporto.

Mantieni la riga sul vedere cosa è successo mentre eri via. Nessun em dash.
