# Task 1 — Architecture and Technical Plan

**Kilo Mode:** Plan  
**Model:** Grok 4.6  
**Status:** Implementation-ready  
**Repo state:** Greenfield. Only `README.md`, `00_SHARED_CONTEXT.md`, and the task brief exist. No Xcode project, Swift sources, or tests yet.

## Locked decisions

- Native Swift + SwiftUI + Swift Charts. No Electron, no third-party metric libraries.
- Four layers stay separate: Collection → History → Interpretation → Presentation.
- Distributed as a notarized `.dmg`, **not** Mac App Store. App Sandbox **off**.
- Hardened Runtime **on** (required for notarization). No extra TCC entitlements in V1.
- Windowed app is primary. Menu bar extra is a compact health glance.
- Deployment target: **macOS 14**. Uses `Observation`, Swift Charts, `MenuBarExtra`, `SMAppService`.
- Product module name: `MacExplainer`. Display name can change later without renaming types.
- History is in-memory only in V1. Retention is a rolling window, not a database.
- Do not treat high used RAM or low free RAM as unhealthy by itself.

---

## 1. App architecture

Keep each concern in its own type. Collectors return raw numbers only. They never produce health words.

| Module | Types | Responsibility |
|---|---|---|
| App composition | `MacExplainerApp`, `AppSession` | `@main`, scenes, wires collectors → store → interpreter → views. Owns the sample timer. |
| System metrics | `SystemMetricsCollector` | Host-level CPU, VM, swap, uptime, thermal, battery. One snapshot per tick. |
| Process metrics | `ProcessMetricsCollector` | PID list, CPU%, RSS, optional energy, display name/icon via `NSRunningApplication` when available. |
| Disk / network | `IOMetricsCollector` | System-wide disk bytes in/out and interface bytes in/out. Delta vs previous sample. |
| History | `MetricsHistoryStore` | Ring buffers. Downsamples older points. No interpretation. |
| Health scoring | `HealthScorer` | Pure function: snapshot + recent history → `HealthLevel` + `HealthSignals`. Deterministic and unit-tested. |
| Explanations | `ExplanationGenerator` | Pure function: signals → `[HealthReason]` plain-English strings. No AppKit/SwiftUI. |
| Interpretation façade | `HealthInterpreter` | Calls scorer then explainer. The only type Presentation should use for “how is my Mac?”. |
| Presentation | `OverviewView`, `AppsView`, `HistoryView`, `AdvancedView`, `SettingsView`, `MenuBarLabel` | SwiftUI only. Reads `AppSession`. Never calls Mach/libproc. |
| Preferences | `AppPreferences` | `@AppStorage` / `UserDefaults`: sample interval, login item, menu bar on/off, history window. |
| Menu bar | `MenuBarExtra` scene | Shows current `HealthLevel` and one-line summary. Click opens main window. |
| Login item | `LoginItemService` | `SMAppService.mainApp` register/unregister. Isolated so Settings does not touch ServiceManagement directly. |

### Data flow

```
Timer (AppSession)
  → collectors (parallel, cooperative)
  → SystemSnapshot + [ProcessSnapshot]
  → MetricsHistoryStore.append
  → HealthInterpreter.interpret(current, history)
  → @Observable AppSession publishes to SwiftUI
```

`AppSession` is the single UI-facing source of truth. Views do not hold collectors.

### Concurrency

- Collectors run on a dedicated `Utility` QoS `DispatchQueue` labeled `metrics.collection`.
- Snapshots are `Sendable` value types.
- UI hops back via `MainActor`.
- Never collect on the main thread.

---

## 2. macOS metric sources

Do not invent Apple APIs. Prefer documented Foundation/AppKit first, then Darwin/Mach/IOKit. Do **not** shell out to `top`, `vm_stat`, `iostat`, or `nettop` in V1.

| Metric | Mechanism | Kind | Notes |
|---|---|---|---|
| Total physical memory | `ProcessInfo.processInfo.physicalMemory` | Public Foundation | Also `sysctl hw.memsize` as a check. |
| Memory pressure | `sysctlbyname("kern.memorystatus_vm_pressure_level")` | Undocumented sysctl | Values used in the field: `0` normal, `1` warn, `2` urgent, `4` critical. Confirm on the build Mac and treat unknown values as “unknown”, not crash. |
| Memory pressure events | `DispatchSource.makeMemoryPressureSource` | Public libdispatch | Event stream, not a polled level. Use as a wake-up / confirmation signal, not the primary gauge. |
| Active / wired / compressed / free / purgeable | `host_statistics64(mach_host_self(), HOST_VM_INFO64, …)` → `vm_statistics64` | Mach | `compressor_page_count`, `wire_count`, `active_count`, `inactive_count`, `free_count`, `purgeable_count`, `internal_page_count`, `external_page_count`. Multiply counts by `vm_kernel_page_size`. |
| App vs cached-ish split | same `vm_statistics64` | Mach | Use `internal_page_count` vs `external_page_count` as the closest public-ish split. Do not label external pages as “free”. |
| Swap used / reserved | `sysctlbyname("vm.swapusage")` → `xsw_usage` | sysctl | `xsu_used`, `xsu_avail`, `xsu_total`. Reliable. |
| Swap activity | `vm_statistics64.swapins` / `swapouts` | Mach | Cumulative page counts. Store deltas for “swap is growing”. |
| Total CPU | `host_statistics(HOST_CPU_LOAD_INFO)` or `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` | Mach | Need previous tick. `% = Δ(user+sys+nice) / Δ(user+sys+nice+idle)`. |
| Per-process CPU | `proc_listpids(PROC_ALL_PIDS)` + `proc_pidinfo(..., PROC_PIDTASKINFO / PROC_PIDTASKALLINFO)` | libproc (Darwin, not Swift-documented) | `pti_total_user` + `pti_total_system` are Mach ticks. CPU% needs previous sample per PID. |
| Per-process memory | same `proc_taskinfo.pti_resident_size` | libproc | RSS, not “memory footprint”. Footprint needs `PROC_PID_RUSAGE` / phys_footprint and is best-effort. |
| Process name / icon | `proc_name` / `proc_pidpath` + `NSRunningApplication` | libproc + AppKit | Prefer `localizedName` + `icon` when the PID maps to a running app. Otherwise last path component. Never show raw PID on Overview. |
| Disk read/write activity | IOKit `IOBlockStorageDriver` statistics (`Bytes (Read/Written)`, `Operations`) | IOKit C API | System-wide only in V1. Iterate `IOServiceGetMatchingServices` for `IOBlockStorageDriver`. Sum children, avoid double-counting partitions if both parent and child publish stats — prefer the driver-level numbers. |
| Network send/receive | `getifaddrs` → `if_data.ifi_ibytes` / `ifi_obytes` | BSD | Skip `lo0`. Sum remaining interfaces. Delta / interval = B/s. |
| Uptime | `ProcessInfo.processInfo.systemUptime` | Public Foundation | `sysctl kern.boottime` if a boot date is needed. |
| Thermal state | `ProcessInfo.processInfo.thermalState` | Public Foundation | `.nominal / .fair / .serious / .critical`. This is **this process’s** view of system thermal state and is the correct public API. |
| Battery / power | IOKit `IOPSCopyPowerSourcesInfo` / `IOPSCopyPowerSourcesList` / `IOPSGetPowerSourceDescription` | IOKit | Percent, charging, AC vs battery. Absent on desktops — model as `BatteryInfo?`. |
| Low Power Mode | `ProcessInfo.processInfo.isLowPowerModeEnabled` | Public Foundation | Informational, not a health failure. |
| Per-process energy (optional) | `proc_pid_rusage` → `rusage_info_v5`/`v6` `ri_energy_nj` / `ri_cycles` | libproc, Apple Silicon | Flag unavailable on Intel. Do not fake a score. Advanced / Apps only. |
| Per-process disk/network | `proc_pid_rusage` I/O and network fields | libproc, best-effort | V1 Advanced only if the struct version is present. Do not fail collection if missing. |

### Explicitly out of V1

- GPU utilization (no supported public API).
- Per-app “Energy Impact” identical to Activity Monitor (undocumented, not stable).
- Fan RPM / SMC keys (private, fragile).
- Window-server / GPU per-process memory.
- Endpoint Security / `sysctl` process lists that need special entitlements.

### Permissions

| Item | V1 choice |
|---|---|
| App Sandbox | **Disabled.** Sandbox hides other processes and blocks useful `proc_pidinfo`. MAS is out of scope. |
| Hardened Runtime | Enabled for notarization. |
| Full Disk Access | Not required and not requested. |
| `com.apple.security.cs.allow-jit` etc. | Not needed. |
| Login item | `SMAppService` — user-controlled in Settings. |

---

## 3. Data model

All snapshots are immutable structs. No classes in Collection / Interpretation except `AppSession` and `MetricsHistoryStore`.

```swift
enum MemoryPressureLevel: Int, Sendable {
    case normal = 0
    case warning = 1
    case urgent = 2
    case critical = 4
    case unknown = -1
}

struct MemoryCounters: Sendable, Equatable {
    var physicalBytes: UInt64
    var freeBytes: UInt64
    var activeBytes: UInt64
    var inactiveBytes: UInt64
    var wiredBytes: UInt64
    var compressedBytes: UInt64
    var internalBytes: UInt64
    var externalBytes: UInt64
    var purgeableBytes: UInt64
    var swapUsedBytes: UInt64
    var swapTotalBytes: UInt64
    var swapins: UInt64
    var swapouts: UInt64
    var pressure: MemoryPressureLevel
}

struct CPUCounters: Sendable, Equatable {
    var userPercent: Double
    var systemPercent: Double
    var idlePercent: Double
    var totalUsedPercent: Double   // user + system + nice
}

struct IORate: Sendable, Equatable {
    var bytesPerSecondIn: UInt64
    var bytesPerSecondOut: UInt64
}

struct BatteryInfo: Sendable, Equatable {
    var percent: Int
    var isCharging: Bool
    var isOnAC: Bool
}

struct SystemSnapshot: Sendable, Equatable {
    var timestamp: Date
    var uptime: TimeInterval
    var cpu: CPUCounters
    var memory: MemoryCounters
    var disk: IORate
    var network: IORate
    var thermal: ProcessInfo.ThermalState
    var battery: BatteryInfo?
    var lowPowerMode: Bool
}

struct ProcessSnapshot: Sendable, Equatable, Identifiable {
    var id: Int32              // pid
    var name: String           // human-readable
    var bundleIdentifier: String?
    var cpuPercent: Double
    var residentBytes: UInt64
    var footprintBytes: UInt64?   // optional
    var energyNanojoulesDelta: UInt64?
    var isApplication: Bool
}

enum HealthLevel: String, Sendable {
    case normal
    case moderateLoad
    case highLoad
    case potentialProblem
}

struct HealthSignals: Sendable, Equatable {
    var cpuSustainedHigh: Bool
    var memoryPressureElevated: Bool
    var swapGrowing: Bool
    var thermalElevated: Bool
    var diskBusy: Bool
    var dominantProcess: ProcessSnapshot?
}

struct HealthReason: Sendable, Equatable, Identifiable {
    var id: String
    var headline: String          // “Your Mac is managing memory normally.”
    var detail: String            // one short supporting sentence
}

struct InterpretedHealth: Sendable, Equatable {
    var level: HealthLevel
    var summary: String           // one sentence for Overview + menu bar
    var reasons: [HealthReason]
    var signals: HealthSignals
}

struct HistoryPoint: Sendable, Equatable {
    var timestamp: Date
    var cpuUsedPercent: Double
    var pressureRaw: Int
    var swapUsedBytes: UInt64
    var diskBytesPerSecond: UInt64
    var networkBytesPerSecond: UInt64
}

enum HistoryWindow: TimeInterval {
    case fiveMinutes = 300
    case thirtyMinutes = 1800
    case twoHours = 7200
}

final class MetricsHistoryStore: @unchecked Sendable {
    // ring buffers keyed by HistoryWindow; append is the only mutation
}

struct AppPreferences {
    var sampleInterval: TimeInterval   // 1, 2, or 5 seconds; default 2
    var historyWindow: HistoryWindow   // default .thirtyMinutes for charts, retain up to .twoHours
    var showsMenuBarExtra: Bool
    var startsAtLogin: Bool
}
```

`HealthScorer` and `ExplanationGenerator` take `SystemSnapshot`, `[ProcessSnapshot]`, and `[HistoryPoint]` and return `InterpretedHealth`. No I/O.

---

## 4. Sampling

| Knob | V1 default | Rationale |
|---|---|---|
| Sample interval | **2 s** (Settings: 1 / 2 / 5) | Fast enough for CPU% and I/O rates; light enough to stay cheap. |
| First CPU/I/O sample | discarded | Percents and rates need a baseline. Show a short “Measuring…” state. |
| UI publish | every successful sample on MainActor | Views render the latest snapshot only. Charts read downsampled history. |
| 5-minute history | keep every sample | ~150 points at 2 s. |
| 30-minute history | store 10 s averages | ~180 points. |
| 2-hour history | store 30 s averages | ~240 points. |
| Process list | top **N = 25** by CPU, plus top **N = 25** by RSS, merged | Do not keep all PIDs in history. |
| Memory budget | history + latest processes only | Upper bound roughly a few hundred `HistoryPoint`s + ≤50 `ProcessSnapshot`s. No images in the store; icons loaded in the view from `NSRunningApplication`. |
| Persistence | none | Restart clears history. Settings persist via `UserDefaults`. |

### Stay light

- One timer, one collection queue, no per-metric timers.
- Reuse previous `proc` sample map for CPU deltas; drop PIDs that disappeared.
- Do not fetch icons during collection. Resolve on the main actor in the Apps view.
- Skip energy/`rusage` unless the Apps or Advanced tab is visible (optional later; V1 may always sample `PROC_PIDTASKINFO` only).
- Collector should typically finish well under 50 ms. If a tick overruns, skip the next tick rather than queueing.
- The app must not appear in its own “what is making my Mac slow?” list unless it exceeds a small CPU threshold (e.g. 5%). Still collect it; just do not highlight it as the cause.

---

## 5. Health model

`HealthScorer` is conservative. High RAM usage alone never raises the level.

### Inputs that may raise severity

1. **Memory pressure** (`kern.memorystatus_vm_pressure_level`) — primary memory signal.
2. **Swap growth** — `ΔswapUsed` or `Δ(swapins+swapouts)` over the last 1–2 minutes, not the mere existence of swap.
3. **Sustained CPU** — `totalUsedPercent` above threshold for several consecutive samples, not a one-tick spike.
4. **Thermal** — `.serious` / `.critical`.
5. **Sustained disk rate** — very high `disk.bytesPerSecond` for multiple samples (busy, not “disk full”).
6. **Dominant process** — one app holding high CPU across samples, used for “what is causing this?”, not for the level by itself.

### Inputs that must not raise severity alone

- Low free RAM
- High active + inactive + wired + compressed (normal macOS caching)
- Any swap used while pressure is normal and swap is not growing
- Battery percent
- Low Power Mode
- High network traffic
- A single 2-second CPU spike

### Thresholds (initial, all named constants in `HealthScorer`)

| Signal | Moderate | High | Potential problem |
|---|---|---|---|
| Pressure | warning for ≥ 15 s | urgent | critical, or urgent ≥ 60 s |
| Swap growth | rising for ≥ 30 s while pressure ≥ warning | rising fast while urgent | swap growing and pressure critical |
| CPU used | ≥ 70% for 20 s | ≥ 85% for 30 s | ≥ 95% for 60 s **and** thermal ≥ fair or one process dominates |
| Thermal | `.fair` | `.serious` | `.critical` |
| Disk | high rate ≥ 30 s | high rate ≥ 60 s with CPU or pressure also elevated | not used alone for Potential problem |

Final level = **max** severity among fired signals. If none fire → `normal`.

### Explanation rules

- One headline summary, then 1–3 reasons.
- Normal memory example: “Your Mac is using memory normally. macOS keeps recently used data in RAM on purpose, so a full memory graph is not a problem by itself.”
- Swap with normal pressure: “macOS is using some disk-backed memory, but memory pressure is still normal.”
- Never say “you are out of RAM” unless pressure is urgent/critical.
- Name the top app only when it is a clear outlier (e.g. ≥ 30% CPU sustained, or largest RSS **and** pressure elevated).

---

## 6. Project structure

Create an Xcode macOS App project at the repo root. Bundle ID: `com.macexplainer.app` (changeable). Team / signing left to the implementing developer.

```
Activity-Monitor-For-Humans/
  MacExplainer.xcodeproj
  MacExplainer/
    MacExplainerApp.swift
    AppSession.swift
    Resources/Assets.xcassets
    MacExplainer.entitlements          # sandbox OFF, hardened runtime ON
    Info.plist                         # only if needed beyond generate-info-plist
    Collection/
      MachVM.swift                     # host_statistics64 wrappers
      Sysctl.swift                     # typed sysctl helpers
      SystemMetricsCollector.swift
      ProcessMetricsCollector.swift
      IOMetricsCollector.swift         # disk + network
      PowerMetricsCollector.swift      # battery + thermal + LPM
    Storage/
      MetricsHistoryStore.swift
    Interpretation/
      HealthScorer.swift
      ExplanationGenerator.swift
      HealthInterpreter.swift
    Presentation/
      OverviewView.swift
      AppsView.swift
      HistoryView.swift
      AdvancedView.swift
      SettingsView.swift
      MenuBarLabel.swift
      Formatters.swift                 # bytes, %, duration — display only
    Settings/
      AppPreferences.swift
      LoginItemService.swift
  MacExplainerTests/
    HealthScorerTests.swift
    ExplanationGeneratorTests.swift
    MetricsHistoryStoreTests.swift
    CPUDeltaTests.swift
  scripts/
    package_dmg.sh                     # later milestone
  00_SHARED_CONTEXT.md
  01_ARCHITECTURE_PLAN_GROK46.md
```

Targets:

- `MacExplainer` — app.
- `MacExplainerTests` — host-side unit tests for scoring, explanations, history downsampling, CPU delta math.

No SPM packages in V1. Darwin/IOKit bridging stays in `Collection/` with thin `@_silgen_name` / Darwin imports only where the Swift overlay is missing.

---

## 7. Development sequence

Each milestone is independently completable. Do not start UI copy that depends on interpretation until milestone 4 exists.

### M0 — Project skeleton

- Create the macOS 14 SwiftUI app + test target.
- Entitlements: sandbox off.
- Empty `AppSession` + tab shell: Overview, Apps, History, Advanced, Settings.
- Confirm `xcodebuild -scheme MacExplainer -destination 'platform=macOS' build` succeeds.

### M1 — System snapshot

- Implement `Sysctl`, `MachVM`, `SystemMetricsCollector`, `PowerMetricsCollector`.
- Deliver `SystemSnapshot` every 2 s without process/IO rates (IO rates can wait one tick).
- Temporary Advanced view dumps raw numbers. No health language.

### M2 — Rates and processes

- CPU deltas, `IOMetricsCollector`, `ProcessMetricsCollector`.
- Discard first sample.
- Apps tab: name, CPU%, memory, sort.

### M3 — History

- `MetricsHistoryStore` with the three windows and downsampling.
- History tab: Swift Charts for CPU, pressure, swap, disk, network.

### M4 — Health layer

- `HealthScorer`, `ExplanationGenerator`, `HealthInterpreter`.
- Unit tests for: high RAM + normal pressure = Normal; warning pressure = Moderate; swap present + normal pressure = Normal; sustained CPU = High; critical pressure = Potential problem.
- Overview switches from raw dumps to health summary + top apps + mini charts.

### M5 — Product UI

- Polish Overview (not an Activity Monitor clone).
- Settings: interval, history window, menu bar toggle, start at login.
- `MenuBarExtra` + `LoginItemService`.
- Formatters: hide PIDs, “swap”, “wired” on Overview; keep them on Advanced.

### M6 — Packaging

- Icon, display name, copyright.
- Notarization-ready hardened runtime.
- `scripts/package_dmg.sh` for a drag-to-Applications DMG.
- Manual pass: app CPU stays low while idle on the Overview tab.

Do not implement large prototype work beyond a throwaway `host_statistics64` / `vm.swapusage` sanity check if an API fails on the developer Mac. If `kern.memorystatus_vm_pressure_level` is missing or always zero, fall back to: pressure unknown + use swap-growth + compressed-memory *trend* only, and surface “pressure unavailable” on Advanced — never invent a pressure number.

---

## 8. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| `kern.memorystatus_vm_pressure_level` is undocumented and may change | Memory health is the product’s core claim | Isolate behind `MemoryPressureLevel`; unknown → do not scare the user; rely on swap growth + thermal + CPU. |
| App Sandbox / MAS | Process list and IOKit become useless | V1 is unsandboxed DMG only. Do not flip sandbox on without a new design. |
| Process visibility | Other users’ processes, some system daemons, and protected apps may return `EPERM` | Skip unreadable PIDs. Show user-visible apps first. Never crash on a single PID. |
| libproc / Mach are not Swift-stable | Overlay changes across SDKs | Keep wrappers tiny and tested against `vm.swapusage` / `physicalMemory` sanity bounds. |
| Hardened Runtime + notarization | Gatekeeper blocks unsigned builds | Enable hardened runtime from M0; staple after notary in M6. No private entitlements. |
| Collector cost | The explainer becomes the heavy app | 2 s default, top-N processes, skip overrun ticks, no CLI scraping, no icon I/O on the sampler. |
| CPU% math errors | Misleading “what is slow?” | Always two-sample deltas; clamp 0…100; ignore first tick; unit-test synthetic tick pairs. |
| RSS vs footprint | Users think RSS is “the memory number” | Overview uses human wording (“using about X”). Advanced labels RSS vs footprint. |
| High RAM misread | Opposite of the product goal | Scorer tests forbid elevating on used-RAM-only fixtures. Copy review on Overview strings. |
| Thermal is process-visible, not SMC | May lag hardware monitors | Use only as a supporting signal. |
| Battery IOKit keys differ | Desktops / some power sources | `BatteryInfo?`; omit the row when nil. |
| Disk double-count | Inflated B/s | Prefer `IOBlockStorageDriver` totals; document if a machine looks wrong. |
| Menu bar + timer + charts | Extra wake-ups | Same `AppSession` sample feeds every surface. No second poller. |
| Start at login | Unexpected background use | Off by default. Clear Settings copy. |

---

## Validation

- `xcodebuild` build with zero warnings where practical.
- `MacExplainerTests` for scorer, explainer, history downsample, CPU deltas.
- Manual: compare order-of-magnitude CPU, RAM total, swap, and top process against Activity Monitor. Do not expect identical Energy Impact or footprint.
- Manual: open a large app and confirm Overview does **not** flip to problem solely because used RAM rose.
- Manual: idle app CPU stays low on Overview.

## Out of scope for V1

Mac App Store, sandbox, persisted multi-day history, GPU, fans, identical Activity Monitor Energy Impact, iOS/iPad, widgets, alerts/notifications, multiple user sessions, remote hosts.

## Implementation note

Another agent should execute M0→M6 in order, preserve this layering, and not mix collection code with health sentences.
