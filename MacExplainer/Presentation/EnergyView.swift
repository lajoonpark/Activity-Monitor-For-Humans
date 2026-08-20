import SwiftUI

struct EnergyView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppPreferences.self) private var preferences

    private var energyGroups: [ProcessGroupStats] {
        session.appGroups
            .filter { $0.energyNanojoulesDelta != nil }
            .sorted { ($0.energyNanojoulesDelta ?? 0) > ($1.energyNanojoulesDelta ?? 0) }
    }

    private var topGroup: ProcessGroupStats? {
        energyGroups.first
    }

    private var hasAnyEnergy: Bool {
        energyGroups.contains { ($0.energyNanojoulesDelta ?? 0) > 0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let top = topGroup {
                    calloutCard(top)
                }
                table
                if !hasAnyEnergy {
                    footnote
                }
                }
                .padding()
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Energy")
        }

    private func calloutCard(_ group: ProcessGroupStats) -> some View {
        HStack(spacing: 10) {
            ProcessIconView(pid: group.pid ?? -1)
            VStack(alignment: .leading, spacing: 2) {
                Text("Using the most energy right now")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(group.name)
                    .font(.title3)
                    .bold()
            }
            Spacer()
            Text(Formatters.watts(group.energyNanojoulesDelta, interval: preferences.sampleInterval))
                .font(.title3)
                .monospacedDigit()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private var table: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("App groups")
                .font(.headline)
            Table(energyGroups) {
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
                    }
                }
                .width(min: 220, ideal: 300)

                TableColumn("Watts") { group in
                    Text(Formatters.watts(group.energyNanojoulesDelta, interval: preferences.sampleInterval))
                        .monospacedDigit()
                }
                .width(min: 90, ideal: 120)
            }
            .frame(minHeight: 200)
        }
    }

    private var footnote: some View {
        Text("Per-process energy is reported by macOS only on some Macs. On others it reports none (—) or 0 W.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}