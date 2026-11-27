# Piano: storico con eventi, più metriche e 7 giorni

## Obiettivo

La finestra History deve permettere di ricostruire cosa è successo nel passato: un registro eventi, un grafico con tutte le metriche e le fasce di assenza o protezione, il dettaglio al passaggio del puntatore, l'esportazione in testo o CSV. Retention di 7 giorni per punti ed eventi.

## Ambito

Dentro:

- `HistoryPoint` con tre campi nuovi opzionali: temperatura, assenza, numero di app in pausa dalla protezione.
- Retention 7 giorni (10 080 punti per minuto).
- Registro eventi persistito in `events.json`, 7 giorni, massimo 5000 eventi. Una riga per fatto: l'evento di un avviso, di una pausa della protezione o del ritorno dell'utente dice se è partita una notifica. Le righe "Notification" restano solo per le notifiche senza evento proprio (StorageWatcher, trends, avviso di calore con utente presente, calore senza colpevole).
- Eventi sullo stato della protezione: spenta, messa in pausa con scadenza, riattivata (a mano o a fine pausa).
- Assenza = solo `Presence.absent` (`isAway`). `passive` conta come presente.
- Grafico a pannelli sovrapposti. Si sceglie un intervallo recente (6 ore, 24 ore, 7 giorni, aggregati oltre le 6 ore) oppure un giorno degli ultimi 7, mostrato al minuto.
- Scheda eventi con filtro per categoria.
- Esportazione: copia eventi come testo, salva eventi come CSV, salva i minuti come CSV.
- Split di `Monitor.swift` (oggi 557 righe) per restare nel limite di dimensione.
- README, sezione `## History`.

Fuori:

- Click su un evento per saltare al grafico.
- Eventi per il riepilogo settimanale e per avvio o chiusura dell'app.
- Righe separate per le notifiche ripetute di un avviso ancora attivo (dopo il cooldown): l'avviso è già nel registro.
- Evento "alert cleared" per gli avvisi ancora attivi quando l'app si chiude, ed eventi di protezione per cambi avvenuti ad app chiusa.
- Qualsiasi cambio a `JSONFileStore`, al formato di `trends.json` o di `ignored.json`.

## Passi

1. Core, punti. Aggiungere `temperatureCelsius`, `isAway`, `pausedApps` opzionali a `HistoryPoint`, passare `record` a una firma con contesto, retention 7 giorni.
   - `Packages/HeatGlanceKit/Sources/HeatGlanceCore/History/HistoryStore.swift` (modificato)
2. Core, stato della protezione. `ProtectionMode` (on, off, paused until) derivato da `ProtectionSettings`.
   - `Packages/HeatGlanceKit/Sources/HeatGlanceCore/Protection/ProtectionSettings.swift` (modificato)
3. Core, eventi. Tipi `HistoryEvent`, `HistoryEventKind`, `HistoryEventCategory`, `HistoryEventLog` con append, trim e i costruttori per avvisi, presenza e stato della protezione. Chiave dell'avviso su `Alert`. Formattazione dei valori in un file a parte.
   - `Packages/HeatGlanceKit/Sources/HeatGlanceCore/History/HistoryEvent.swift` (nuovo)
   - `Packages/HeatGlanceKit/Sources/HeatGlanceCore/History/HistoryEventValue.swift` (nuovo)
   - `Packages/HeatGlanceKit/Sources/HeatGlanceCore/Rules/RuleDefinition.swift` (modificato: `Alert.activeRuleID`)
4. Core, serie per il grafico. `HistoryRange`, `HistoryWindow` (intervallo recente o giorno), `HistoryBucket`, aggregazione, segmenti per i buchi, fasce, ricerca del bucket sotto il puntatore.
   - `Packages/HeatGlanceKit/Sources/HeatGlanceCore/History/HistorySeries.swift` (nuovo)
5. Core, esportazione. CSV dei punti, CSV degli eventi, testo degli eventi.
   - `Packages/HeatGlanceKit/Sources/HeatGlanceCore/History/HistoryExport.swift` (nuovo)
6. Test Core.
   - `Packages/HeatGlanceKit/Tests/HeatGlanceCoreTests/Fixtures.swift` (modificato: parametro temperatura)
   - `Packages/HeatGlanceKit/Tests/HeatGlanceCoreTests/HistoryStoreTests.swift` (nuovo)
   - `Packages/HeatGlanceKit/Tests/HeatGlanceCoreTests/HistoryEventTests.swift` (nuovo)
   - `Packages/HeatGlanceKit/Tests/HeatGlanceCoreTests/HistorySeriesTests.swift` (nuovo)
   - `Packages/HeatGlanceKit/Tests/HeatGlanceCoreTests/HistoryExportTests.swift` (nuovo)
7. System, notifiche. `NotificationPayload` dice se la notifica va nel registro come riga a sé; `Notifier` espone una callback chiamata a ogni `send`.
   - `Packages/HeatGlanceKit/Sources/HeatGlanceSystem/Notifications/NotificationCategories.swift` (modificato)
   - `Packages/HeatGlanceKit/Sources/HeatGlanceSystem/Notifications/Notifier.swift` (modificato)
8. App, split di Monitor senza cambi di comportamento. Spostare persistenza, consegna notifiche e observer in due estensioni.
   - `HeatGlance/Monitor.swift` (modificato)
   - `HeatGlance/Monitor+Persistence.swift` (nuovo)
   - `HeatGlance/Monitor+Notifications.swift` (nuovo)
9. App, registrazione eventi e contesto dei punti in Monitor: avvisi, notifiche, protezione (app e stato), azioni manuali, presenza, salvataggio di `events.json`.
   - `HeatGlance/Monitor.swift`, `HeatGlance/Monitor+Persistence.swift`, `HeatGlance/Monitor+Notifications.swift` (modificati)
10. App, UI. Spostare la finestra in `HeatGlance/Views/History/`, tre schede (Chart, Events, This week), menu Export.
    - `HeatGlance/Views/HistoryView.swift` (eliminato)
    - `HeatGlance/Views/History/HistoryView.swift` (nuovo)
    - `HeatGlance/Views/History/HistoryChartView.swift` (nuovo)
    - `HeatGlance/Views/History/HistoryWindowPicker.swift` (nuovo)
    - `HeatGlance/Views/History/HistoryMetricChart.swift` (nuovo)
    - `HeatGlance/Views/History/HistoryDetailView.swift` (nuovo)
    - `HeatGlance/Views/History/HistoryEventsView.swift` (nuovo)
    - `HeatGlance/Views/History/WeeklyReportView.swift` (nuovo, contenuto spostato dalla vecchia scheda)
    - `HeatGlance/Views/History/HistoryExporter.swift` (nuovo)
    - `HeatGlance/HeatGlanceApp.swift` (modificato: dimensione finestra)
11. README, sezione `## History`, e voce `changes/` finale (`README.md` in questa cartella) a lavoro finito.
    - `README.md` (modificato)
    - `changes/2026-11-27_09-17_history-events-and-metrics/README.md` (nuovo, a fine lavoro)

## Verifica

Sul client, via ssh (non sul server):

- `ssh client '$SHELL -lc "cd <cartella progetto sul client> && ./test.sh"'`: tutti i test passano, compresi i nuovi.
- `ssh client '$SHELL -lc "cd <cartella progetto sul client> && ./build.sh"'`: build senza errori né warning nuovi.

Manuale sul Mac:

- Un `history.json` creato dalla versione precedente si carica: il grafico mostra i punti vecchi, la temperatura parte vuota per quei minuti.
- 6 ore e un giorno scelto mostrano un punto per minuto; 24 ore e 7 giorni aggregano. Il passaggio del puntatore aggiorna il dettaglio su tutti i pannelli insieme e resta fluido anche nella vista di un giorno intero.
- Un avviso che notifica produce una sola riga, con l'indicazione della notifica; nessuna riga "Notification" duplicata.
- Con l'override thermal (debug) su serious e l'utente assente: compaiono la fascia arancione, le righe di app messe in pausa (con notifica) e riprese.
- Spegnere la protezione dal menu e dalle impostazioni, metterla in pausa per un'ora, riattivarla: ogni passaggio produce una riga.
- Suspend e Quit dal menu compaiono nel registro con app e valore.
- Export: il testo incollato e i due CSV aprono correttamente in Numbers.
- `grep -rn "—" HeatGlance README.md` non trova em dash nei file toccati.
