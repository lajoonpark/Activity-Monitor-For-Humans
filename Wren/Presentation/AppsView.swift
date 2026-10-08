import SwiftUI

/// How a row travels to its new rank in the leaderboard. Short moves glide so
/// the ledger reads as re-sorting; long moves fade so a row never streaks
/// across half the list.
enum RowTravel {
    case glide, fade

    static let glideSpots = 4

    static func classify(fromRank: Int, toRank: Int) -> RowTravel {
        abs(fromRank - toRank) <= glideSpots ? .glide : .fade
    }
}

/// One rendered row. The token turns a fade into a change of identity, which
/// is how SwiftUI is told to let a row go and bring it back rather than move it.
private struct LeaderboardRow: Identifiable {
    let group: ProcessGroupStats
    var token: Int
    let transition: AnyTransition

    var id: String { "\(group.id)#\(token)" }
}

struct AppsView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var sortKey: SortKey = .cpu
    @State private var sortAscending = false
    @State private var pendingGroup: ProcessGroupStats?
    @State private var quitError: String?
    @State private var rows: [LeaderboardRow] = []
    @State private var ranks: [String: Int] = [:]

    enum SortKey { case name, cpu, memory }

    private var sortedGroups: [ProcessGroupStats] {
        let groups = session.appGroups
        switch sortKey {
        case .name:
            return groups.sorted { sortAscending ? $0.name < $1.name : $0.name > $1.name }
        case .cpu:
            return groups.sorted { sortAscending ? $0.cpuPercent < $1.cpuPercent : $0.cpuPercent > $1.cpuPercent }
        case .memory:
            return groups.sorted { sortAscending ? $0.memoryBytes < $1.memoryBytes : $0.memoryBytes > $1.memoryBytes }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionEyebrow(title: "What's using your Mac")

                if session.state != .active {
                    waitingState
                } else if sortedGroups.isEmpty {
                    emptyState
                } else {
                    Text("Every app is grouped together with the pieces it runs underneath, so the list reads the way you think about your Mac.")
                        .font(Typeface.prose(13))
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)

                    ledger
                }
            }
            .padding(20)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.paper)
        .onAppear { recomputeRows() }
        .onChange(of: session.appGroups) { _, _ in recomputeRows() }
        .onChange(of: sortKey) { _, _ in recomputeRows() }
        .onChange(of: sortAscending) { _, _ in recomputeRows() }
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

    private var ledger: some View {
        VStack(alignment: .leading, spacing: 0) {
            LedgerHeader {
                SortableHeader(title: "App", entry: MetricGlossary.processes, isActive: sortKey == .name, isAscending: sortAscending) {
                    toggle(.name)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                SortableHeader(title: "CPU", entry: MetricGlossary.cpuApp, isActive: sortKey == .cpu, isAscending: sortAscending, width: 74) {
                    toggle(.cpu)
                }
                SortableHeader(title: "Memory", entry: MetricGlossary.memoryApp, isActive: sortKey == .memory, isAscending: sortAscending, width: 96) {
                    toggle(.memory)
                }
                Text(" ")
                    .frame(width: 62)
            }

            ForEach(rows) { row in
                AppRow(group: row.group) {
                    pendingGroup = row.group
                }
                .transition(row.transition)
            }
        }
        .paperCard(padding: 8)
    }

    /// Rebuilds the rendered rows, gliding near moves and fading far ones.
    /// A fade is expressed as a new identity so the row is released and
    /// returned instead of dragged across the list.
    private func recomputeRows() {
        let groups = sortedGroups
        // A long move fades out and then back in rather than streaking across
        // the list. Under Reduce Motion the fade is brief and does not move.
        let fade: AnyTransition = reduceMotion
            ? .asymmetric(
                insertion: .opacity.animation(.easeOut(duration: 0.2).delay(0.2)),
                removal: .opacity.animation(.easeOut(duration: 0.2))
            )
            : .asymmetric(
                insertion: .opacity.animation(Motion.drift.delay(0.2)),
                removal: .opacity.animation(Motion.drift)
            )
        let arrive: AnyTransition = .opacity.combined(with: .move(edge: .top))
        let tokens = Dictionary(uniqueKeysWithValues: rows.map { ($0.group.id, $0.token) })

        var updated: [LeaderboardRow] = []
        updated.reserveCapacity(groups.count)
        for (rank, group) in groups.enumerated() {
            let travel = ranks[group.id].map { RowTravel.classify(fromRank: $0, toRank: rank) } ?? .glide
            let token = (tokens[group.id] ?? 0) + (travel == .fade ? 1 : 0)
            updated.append(LeaderboardRow(group: group, token: token, transition: travel == .fade ? fade : arrive))
        }

        withAnimation(Motion.respecting(Motion.settle, reduceMotion: reduceMotion)) {
            rows = updated
        }
        ranks = Dictionary(uniqueKeysWithValues: groups.enumerated().map { ($1.id, $0) })
    }

    private var waitingState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Taking a reading\u{2026}")
                .font(Typeface.proseEmphasis(16))
                .foregroundStyle(Palette.ink)
            Text("Your apps appear as soon as your Mac has been measured.")
                .font(Typeface.prose(13.5))
                .foregroundStyle(Palette.inkSoft)
        }
        .paperCard()
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No apps to show yet.")
                .font(Typeface.proseEmphasis(16))
                .foregroundStyle(Palette.ink)
            Text("The list fills in as soon as your Mac has been measured.")
                .font(Typeface.prose(13.5))
                .foregroundStyle(Palette.inkSoft)
        }
        .paperCard()
    }

    private func toggle(_ key: SortKey) {
        if sortKey == key {
            sortAscending.toggle()
        } else {
            sortKey = key
            sortAscending = (key == .name)
        }
    }
}

private struct AppRow: View {
    let group: ProcessGroupStats
    let onQuit: () -> Void

    @State private var isHovering = false

    var body: some View {
        LedgerRow {
            ProcessIconView(pid: group.pid ?? -1)

            ProcessNameCell(
                name: group.name,
                bundleIdentifier: group.bundleIdentifier,
                detail: caption,
                font: Typeface.label(13)
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            MetricValue(text: Formatters.percent(group.cpuPercent), font: Typeface.data(12.5))
                .frame(width: 62, alignment: .trailing)
            MetricValue(text: Formatters.bytes(group.memoryBytes), font: Typeface.data(12.5), color: Palette.inkSoft)
                .frame(width: 84, alignment: .trailing)

            Button("Quit", action: onQuit)
                .buttonStyle(.plain)
                .font(Typeface.label(11))
                .foregroundStyle(Palette.health(.potentialProblem))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Palette.health(.potentialProblem).opacity(isHovering ? 0.14 : 0))
                )
                .frame(width: 54)
                .opacity(isHovering ? 1 : 0)
                .disabled(ProcessActions.isProtected(group: group))
                .help(ProcessActions.isProtected(group: group) ? "This app can't be quit from here." : "Quit \(group.name)")
                .accessibilityHidden(!isHovering)
        }
        .onHover { hovering in
            withAnimation(Motion.reveal) { isHovering = hovering }
        }
    }

    private var caption: String {
        var parts: [String] = []
        parts.append(group.processCount == 1 ? "1 process" : "\(group.processCount) processes")
        if group.isApplication { parts.append("App") }
        return parts.joined(separator: "  \u{00B7}  ")
    }
}
