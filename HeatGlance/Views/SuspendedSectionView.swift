import SwiftUI

struct SuspendedSectionView: View {
    @Environment(Monitor.self) private var monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                MenuSectionHeader(title: "Paused by protection")
                Spacer()
                Button("Resume all") { monitor.resumeAllSuspended() }
                    .controlSize(.small)
            }
            ForEach(monitor.suspendedGroups, id: \.groupID) { group in
                HStack {
                    Text(group.displayName)
                        .font(.callout)
                        .lineLimit(1)
                    Spacer()
                    Button("Resume") {
                        monitor.resume(groupID: group.groupID)
                    }
                    .controlSize(.small)
                }
            }
        }
    }
}
