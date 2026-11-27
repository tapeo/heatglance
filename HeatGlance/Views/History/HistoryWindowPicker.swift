import Foundation
import SwiftUI

import HeatGlanceCore

struct HistoryWindowPicker: View {
    @Binding var window: HistoryWindow

    var body: some View {
        HStack(spacing: 10) {
            Picker("Range", selection: rangeSelection) {
                ForEach(HistoryRange.allCases) { range in
                    Text(range.title).tag(Optional(range))
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 280)

            Menu(dayMenuTitle) {
                ForEach(HistoryWindow.availableDays(now: Date()), id: \.self) { day in
                    Button(dayTitle(day)) {
                        window = .day(day)
                    }
                }
            }
            .fixedSize()

            Spacer()
        }
    }

    private var rangeSelection: Binding<HistoryRange?> {
        Binding(
            get: {
                guard case let .recent(range) = window else {
                    return nil
                }
                return range
            },
            set: { range in
                guard let range else {
                    return
                }
                window = .recent(range)
            }
        )
    }

    private var dayMenuTitle: String {
        guard let day = window.dayStart() else {
            return "Day"
        }
        return dayTitle(day)
    }

    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) {
            return "Today"
        }
        if calendar.isDateInYesterday(day) {
            return "Yesterday"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: day)
    }
}
