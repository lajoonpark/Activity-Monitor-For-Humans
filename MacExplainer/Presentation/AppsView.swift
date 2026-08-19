import SwiftUI

struct AppsView: View {
    @Environment(AppSession.self) private var session
    @State private var sortOrder = [KeyPathComparator(\ProcessSnapshot.cpuPercent, order: .reverse)]

    var body: some View {
        Table(session.processes.sorted(using: sortOrder), sortOrder: $sortOrder) {
            TableColumn("App") { process in
                HStack(spacing: 8) {
                    ProcessIconView(pid: process.id)
                    Text(process.name)
                        .lineLimit(1)
                    if process.isApplication {
                        Image(systemName: "app.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .width(min: 220, ideal: 300)

            TableColumn("CPU %") { process in
                Text(Formatters.percent(process.cpuPercent))
                    .monospacedDigit()
            }
            .width(min: 70, ideal: 90)

            TableColumn("Memory") { process in
                Text(Formatters.bytes(process.residentBytes))
                    .monospacedDigit()
            }
            .width(min: 90, ideal: 110)
        }
        .navigationTitle("Apps")
    }
}
