# Feature Batch — Process Grouping, Energy Tab, Quit, Menu Bar Metrics

**Project:** Activity-Monitor-For-Humans (MacExplainer, SwiftUI module / Observation / XcodeScheme `MacExplainer`, macOS 14 target)

## Locked product decisions

1. **Subprocess combining (Apps + Overview + Energy):** combined rows are named after the top-level process ("Opera") and show a child-process count ("Opera · 12 processes"). No expandable child rows. Grouping key priority: bundle identifier → parent-pid chain → process name.
2. **Energy tab** shows an honest watts estimate per app group (`ΔenergyNanojoules / sample interval`, labeled "about X W"). It is **not** Activity Monitor's "Energy Impact" column, which relies on undocumented/private APIs and was flagged out-of-V1-scope (`.kilo/plans/1787126567013-architecture-plan.md:92`). A top-consumer callout heads the tab ("Using the most energy right now: **Opera** · about 2.4 W").
3. **Energy grouping reuses the same combined-process logic as feature 1.**
4. **Quit processes:** a Quit button on every Apps row (group-level), gated behind a confirm alert, calling a graceful `kill(pid, SIGTERM)`. Refusals (protected/system processes) surface a non-fatal error alert. The app's own PID row cannot be quit (button disabled).
5. **Menu bar metrics:** new `MenuBarMetricsStyle` preference — `.popupOnly` (default) or `.inMenuBar`. When `.inMenuBar`, the menu bar label text becomes compact CPU + RAM in use ("12% 7.2G"). The popup **always** shows CPU % and RAM-about-used lines. "About used" RAM uses one shared definition (`physicalBytes - freeBytes`) across popup, menu-bar text, and Overview.
6. Units stay honest everywhere. Never invent an "Energy Impact" number.

---

## Step 1 — Models.swift: parent pid + group model

File: `MacExplainer/Models.swift`

1. Add `parentPid: Int32?` to `ProcessSnapshot` (Models.swift:58).
2. Add the grouping model (same file, no AppKit):

```swift
struct ProcessGroupStats: Sendable, Equatable, Identifiable {
    var id: String            // stable group key: bundleID or resolved parent name
    var name: String          // display name of the top process (or child fallback)
    var pid: Int32?           // top process pid — used for the icon and Quit action
    var isApplication: Bool
    var cpuPercent: Double    // combined
    var residentBytes: UInt64 // combined
    var energyNanojoulesDelta: UInt64?  // combined (nil when no member reports energy)
    var processCount: Int32
}
```

## Step 2 — `ProcessMetricsCollector`: parent PID + energy deltas

File: `MacExplainer/Collection/ProcessMetricsCollector.swift`

- Extend `RawSample` (line 29) with `parentPid: Int32?`, populated from `proc_pidinfo(pid, PROC_PID_PROC_BSDINFO)` → `proc_bsdinfo`, reading `pbi_ppid`. Follow the existing failing gracefully (`taskInfo`/`executablePath` pattern at ProcessMetricsCollector.swift:115-127): if the call/resize fails, record `nil`.
- Extend the per-PID previous-sample map so it also tracks energy. The old code stores `[Int32: ProcessCPUSample]` (line 37). Replace with:

```swift
private struct ProcessPreviousSample: Equatable {
    let totalTicks: UInt64
    let energyNanojoules: UInt64?
}
```

(Keep `CPUPercent.percent` signature; it reads `.totalTicks` on `ProcessCPUSample` — either keep that struct for CPU and add energy to it, or a small parallel map. Prefer one map keyed by pid carrying both.)

- Populate energy from `proc_pid_rusage(pid, RUSAGE_INFO_V5, &info)` if the SDK overlays it (name may differ; the struct had `ri_energy_nj`, `ri_footprint_bytes`, `ri_cycles`). Wrap behind a private helper returning `UInt64?` so collection never fails when the overlay is missing or the state is zero. Do **not** shell out.
- On each publish pass, compute `energyNanojoulesDelta = currentEnergy - previousEnergy` (nil if either side missing; `0` is legal but surface as "0 W").
- New processes (first sample) still return nil from the whole method — no CPU or energy delta exists yet.
- `applyingAppMetadata` (line 74) must now pass through `parentPid` unchanged.
- Per-process energy on Apple Silicon may report 0 or be unsupported — collection must never crash on it.

Cost control: parent-PID reads apply to all PIDs (identical to the cheap `proc_pid_info` already called per PID). The optional `proc_pid_rusage` energy check must only run for the final merged top-N set, or must stay well under the 50 ms budget. Restructure `collectRawSamples` (line 90) to append parentPid in the same loop.

## Step 3 — `AppSession`: flat list stays; groups added

File: `MacExplainer/AppSession.swift`

- Keep `processes: [ProcessSnapshot]` as-is (health scorer + Advanced view depend on it).
- The metadata pass in `publish` (`applyingAppMetadata(to: batch.processes)`) must preserve `parentPid`; the batch processes already carry it from Step 2.
- New observable property:

```swift
var appGroups: [ProcessGroupStats] = []
```

- Build it after metadata in `publish` by calling a pure static `ProcessGrouping.buildGroups(from: processes) -> [ProcessGroupStats]`.
- If needed for Views/Overview, also expose `topEnergyGroup: ProcessGroupStats?` and `menuBarMetricsLine` (Step 7).

New pure grouping unit — new file `MacExplainer/Collection/ProcessGrouping.swift` (no AppKit calls, deterministic, sends nothing):

```swift
enum ProcessGrouping {
    // group key rules for the SAME published slice:
    //  1. bundleIdentifier != nil           -> bundleID key
    //  2. parentPid walks up the same-slice map and lands on an app /
    //     top process -> that top process's key
    //  3. otherwise -> "name:<displayName>"
    static func buildGroups(from: [ProcessSnapshot]) -> [ProcessGroupStats]
}
```

Behavioural contract:
- Sum CPU and RSS across members; count members faithfully (parent + children).
- Member with a bundle ID groups with any other member sharing that bundle even without parent-PID links (catches "Google Chrome Helper" variants).
- A sole app with no helpers becomes a group of size 1.
- Name: the top visible process's localized name. When a parent has an obscure executable name ("Opera Rocker") and the child is named generically, keep the parent's name. If the parent is missing from the slice, fall back to the child's own localized name.
- `pid` = the top (root-most) sampled process — used for icon + Quit.
- `energyNanojoulesDelta` = sum over members of their delta; nil if no member has energy at all.
- Each process appears in exactly one group.
- If a helper pid dies between samples the next slice naturally re-groups; no tombstones.

Merge limit: group rows face the same top-25 CPU / top-25 RSS selection living in `MetricsEngine.topProcesses` (AppSession.swift:163) — the grouping function must accept parent history NOT present (parent's pid not in slice). Groups are still formed (the child becomes root with child name). This is expected and fine.

## Step 4 — Apps + Overview tables: combined rows

Files: `MacExplainer/Presentation/AppsView.swift`, `MacExplainer/Presentation/OverviewView.swift`

- AppsView.swift:8 — table source changes from `session.processes` to `session.appGroups`:
  - App column: `Text(group.name)` with caption `Text("\(group.processCount) processes").font(.caption2).foregroundStyle(.secondary)` under it (kept `lineLimit(1)`). Icon: reuse `ProcessIconView(pid: group.pid)` (defined OverviewView.swift:146).
  - CPU %: `Formatters.percent(group.cpuPercent)`.
  - Memory: `Formatters.bytes(group.residentBytes)`.
  - Sorting key path must switch to the group struct (`KeyPathComparator(\ProcessGroupStats.cpuPercent...)`).
- OverviewView.swift `topApps` (line 65) — same swap: top 5 appGroups by combined CPU, captions with `processCount`, combined CPU/RSS. Keep `.prefix(5)`.

## Step 5 — Energy tab

New file: `MacExplainer/Presentation/EnergyView.swift`

- Layout (`ScrollView` → `VStack`):
  1. Callout card: top energy group (`appGroups` with a non-nil energy delta, sorted desc, `.first`), headline "Using the most energy right now", bold group name, watts.
  2. Full table: appGroups with energy, sorted by watts desc. Columns: App (icon + name + count caption), Watts.
  3. Footnote (caption, secondary): "Per-process energy is reported by macOS only on some Macs. On others it reports none (—) or 0 W." Use only when no data or all-zero.
- Add `Formatters.watts` in `MacExplainer/Presentation/Formatters.swift`:

```swift
static func watts(_ deltaNanojoules: UInt64?, interval: TimeInterval) -> String {
    guard let delta, interval > 0 else { return "—" }
    let joules = Double(delta) / 1_000_000_000
    let watts = joules / interval           // sample interval in seconds
    if watts == 0 { return "0 W" }
    return "about \(String(format: "%.1f", watts)) W"
}
```

- Pass the current sample interval into the view. The sample timer fires on `AppPreferences.sampleInterval`, so `EnergyView` reads it via `@Environment(AppPreferences.self)` and formats the watts string there. Keep `ProcessGroupStats` pure (no display logic in `AppSession`).
- Register the tab in `MacExplainerApp.swift` ContentView's TabView (line 13-23), after Apps:

```swift
EnergyView()
    .tabItem { Label("Energy", systemImage: "bolt") }
```

If the SwiftUI system image name is invalid, use `"power"` and verify at compile/manual pass.

## Step 6 — Quit processes (all app rows)

File: `MacExplainer/Presentation/AppsView.swift` (+ small helper in `MacExplainer/Collection/ProcessActions.swift` or inline; keep `kill` usage in one place).

1. Add an "Actions" column; each row gets `Button("Quit", role: .normal)` (disabled when `group.pid == ProcessInfo.processInfo.processIdentifier`, i.e. MacExplainer itself).
2. On tap → store the pending group; drive a confirm alert following the existing `SettingsView.swift:51` pattern:

```swift
.alert("Quit \(pendingGroup.name)?", isPresented: ...) {
    Button("Cancel", role: .cancel) { pendingGroup = nil }
    Button("Quit", role: .destructive) { quit(pendingGroup!) ; pendingGroup = nil }
} message: {
    Text("Unfinished work in " + pendingGroup.name + " may be lost.")
}
```

3. Termination (graceful):

```swift
// returns Bool / throws as available; Safely Darwin `kill(pid, SIGTERM)`.
// Never force-quit (SIGKILL) — SIGTERM lets the app save and exit first.
```

- If the target pid is a helper with an app parent, killing the group's top process kills the whole set — that is the intended umbrella behavior we surface to the user.
- If `kill` fails (including `EPERM` for protected/system processes), show a transient non-fatal alert: "The system could not quit this process."
- After a successful quit, keep the row until the next publish tick (engine re-samples and drops it).
- The plain wrinkle persists: some rows are thin system helpers with `isApplication == false` and no bundle ID — "all apps" is the chosen behavior; gate the Quit button to app-level groups by masking obvious system PIDs (e.g. `launchd`, `loginwindow`) with a name allowlist. Preference does not alter this scope in this batch.

## Step 7 — Menu bar CPU + RAM

Files: `MacExplainer/Presentation/SettingsView.swift`, `MacExplainer/Presentation/MenuBarLabel.swift`, `MacExplainer/Settings/AppPreferences.swift`, `MacExplainer/MacExplainerApp.swift`

1. `AppPreferences.swift` — new enum + key + property (persisted like the rest):

```swift
enum MenuBarMetricsStyle: String, Sendable {
    case popupOnly
    case inMenuBar
}
var menuBarMetrics: MenuBarMetricsStyle   // Key "preferences.menuBarMetrics", default .popupOnly
```

2. `SettingsView.swift` ("Menu bar" section) — segmented picker with two options: "In pop-up only" / "In menu bar".
3. `MacExplainerApp.swift` line ~61 — pass preferences into the label:

```swift
MenuBarLabel(session: session, preferences: preferences)
```

4. `MenuBarLabel.swift`:

```swift
var body: some View {
    HStack(spacing: 4) {
        Image(systemName: "waveform.path.ecg").foregroundStyle(levelColor)
        if preferences.menuBarMetrics == .inMenuBar, let line = session.menuBarMetricsLine, !line.isEmpty {
            Text(line).font(.caption2).monospacedDigit().foregroundStyle(.secondary)
        }
    }
}
```

Currently `MenuBarLabel` is `View` direct member with the extra context? The label: closure is a `View`. Add an `@Environment(AppPreferences.self) private var preferences` member instead — the `MenuBarExtra(label:)` in `MacExplainerApp` already puts `preferences` into the scene environment (`.environment(preferences)` on MenuBarContent). Verify environment scoping; if the label closure can't read the env, pass preferences explicitly as the initializer param.

5. `AppSession.swift` — expose the compact line (main-actor computed):

```swift
var menuBarMetricsLine: String {
    guard let snapshot = current else { return "" }
    let cpu = Formatters.percent(snapshot.cpu.totalUsedPercent)
    let used = snapshot.memory.physicalBytes - snapshot.memory.freeBytes
    return "\(cpu) \(Formatters.bytes(used))"
}
```

- `AppSession` imports only Foundation; `Formatters` lives in Presentation and imports SwiftUI, so do not import `Formatters` into `AppSession`. Instead expose raw pieces on `AppSession` — `cpuPercent` (Double) and `usedBytes` (UInt64) — and let the MenuBar view format them.

6. `MenuBarContent.swift` popup — always show a metrics line above the Divider:

```swift
if let snapshot = session.current {
    let used = snapshot.memory.physicalBytes - snapshot.memory.freeBytes
    Text("CPU \(Formatters.percent(snapshot.cpu.totalUsedPercent))  \u{00B7}  RAM about \(Formatters.bytes(used))")
        .font(.callout)
        .monospacedDigit()
}
```

Widen the popup frame from `width: 280` if the line wraps (test).

7. Keep the shared RAM definition (`physicalBytes - freeBytes`) in one extension point so Overview, popup, and menu-bar text cannot drift. Add to `Models.swift`: `extension MemoryCounters { var usedBytes: UInt64; var usedFraction: Double }`. Update OverviewView's `cpuMemoryLine` (line 61) to use the same extension when sensible (it currently sums active+wired+compressed; aligning the definition is a small task-level improvement, optional).

## Step 8 — Tests

Mirror `MacExplainerTests` style (existing: voter tests run under `xcodebuild test -scheme MacExplainer -destination 'platform=macOS'`).

1. New `ProcessGroupingTests.swift` — pure-function tests:
   - "Opera Helper under parent → one group; name Opera; processCount; CPU/mem sums".
   - "Parent pid absent from slice → child becomes its own group with its own name".
   - "Two processes sharing a bundle → group together".
   - "App without helpers → group of size 1".
2. New `EnergyDeltaTests.swift` (mirror CPUDeltaTests) — previous/current energy sample deltas; nil propagation (missing previous, missing current, reset counters).
3. New `FormattersTests.swift` — `Formatters.watts` :: conversions (delta nanojoules + 2s interval → watts), 0 → "0 W", nil → "—".
4. Existing suites stay green (HealthScorer etc. — no data-shape changes to snapshot fields they read).

## Step 9 — Manual validation

- Fresh-launch corrections: per project memory, **quit any stale running MacExplainer instance** before manual tests, else old UI masks changes.
- Hard: launch browsers/library apps with helpers; confirm multiple helpers fold under one parent row with counts.
- Energy tab on this Mac (Apple Silicon): expect "—"/0 W + footnote — verify no crash.
- Quit: pick an expendable app → sheet → quit → row disappears next sample; protected pids preserve (Alert surfaces expected EPERM).
- Menu bar: flip from Settings — when `.inMenuBar` the label gains the compact text in real time; `.popupOnly` hides it; popup always shows the CPU/RAM line.
- `xcodebuild -scheme MacExplainer -destination 'platform=macOS' build` zero warnings (new code) and all tests pass.

## Risks

| Risk | Mitigation |
|---|---|
| `proc_pid_rusage` fields/constant unavailable in this SDK overlay | Isolate behind helper; energy rows render "—" with the footnote; no invented numbers. |
| Apple Silicon reports 0/no energy | Footnote text; UI never implies it represents a battery drain |
| parent-PID `proc_pidinfo` adds syscalls per process | Same loop as existing collection; verify tick stays well under 50 ms; back off by sampling rusage only for the final merged top-N |
| Killing the parent instead of a child | Confirm copy states relations; that is the intended group semantic |
| EPERM on `kill` | Graceful alert; never treat as failure of the app |
| Group naming surprises (helper appears as own group when its parent escapes the slice) | Documented behavior of the top-N slice; manual test with busy browser |
| RAM definition drift between popup / menu-bar / Overview | One `MemoryCounters.usedBytes` extension, used everywhere |

## Out of scope for this batch

- MS-identical "Energy Impact" digits and 12 h averages (needs private APIs; does not exist in samples).
- Persistent sort/filter preferences for the new tables.
- Energy sparks/history chart — current and per-sample only.
- Quit via keyboard shortcut or Advanced-table rows (only Apps group rows in this batch).