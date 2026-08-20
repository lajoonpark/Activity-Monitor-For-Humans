import SwiftUI

struct AppsView: View {
    @Environment(AppSession.self) private var session
    @State private var sortOrder = [KeyPathComparator(\ProcessGroupStats.cpuPercent, order: .reverse)]
    @State private var pendingGroup: ProcessGroupStats?
    @State private var quitError: String?

    var body: some View {
        Table(session.appGroups.sorted(using: sortOrder), sortOrder: $sortOrder) {
            TableColumn("App") { group in
                HStack(spacing: 8) {
                    ProcessIconView(pid: group.pid ?? -1)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(group.name)
                            .lineLimit(1)
                        Text("\(group.processCount) processes")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if group.isApplication {
                        Image(systemName: "app.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .width(min: 220, ideal: 300)

            TableColumn("CPU %") { group in
                Text(Formatters.percent(group.cpuPercent))
                    .monospacedDigit()
            }
            .width(min: 70, ideal: 90)

            TableColumn("Memory") { group in
                Text(Formatters.bytes(group.residentBytes))
                    .monospacedDigit()
            }
            .width(min: 90, ideal: 110)

            TableColumn("Actions") { group in
                Button("Quit") {
                    pendingGroup = group
                }
                .disabled(ProcessActions.isProtected(group: group))
            }
            .width(min: 70, ideal: 80)
        }
        .navigationTitle("Apps")
        .alert("Quit \(pendingGroup?.name ?? "")?", isPresented: Binding(
            get: { pendingGroup != nil || quitError != nil },
            set: { if !$0 { pendingGroup = nil; quitError = nil } }
        )) {
            if quitError != nil {
                Button("OK", role: .cancel) { quitError = nil }
            } else {
                Button("Cancel", role: .cancel) { pendingGroup = nil }
                Button("Quit", role: .destructive) {
                    if let group = pendingGroup {
                        ProcessActions.quit(group: group) { error in
                            quitError = error
                        }
                    }
                    pendingGroup = nil
                }
            }
        } message: {
            if quitError != nil {
                Text("The system could not quit this process.")
            } else {
                Text("Unfinished work in \(pendingGroup?.name ?? "") may be lost.")
            }
        }
    }
}
