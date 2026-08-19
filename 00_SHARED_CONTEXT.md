# Shared Project Context — macOS Activity Explainer

## Give this to Kilo first

You are working on a native macOS application whose purpose is to translate Activity Monitor-style system information into language that ordinary people can understand.

## Product goal

Build a lightweight native macOS app that a user can download and install as a `.dmg`.

The app should collect useful Mac system metrics and present them in a simple, reassuring, accurate way without requiring the user to understand technical terms such as swap, memory pressure, system CPU, cached RAM, process IDs, disk I/O, or network throughput.

The app should answer questions such as:

- Is my Mac running normally?
- Is my Mac actually low on memory?
- What app is using the most memory?
- What is making my Mac feel slow?
- Is high RAM usage actually a problem?
- Is CPU usage unusually high?
- Is macOS using swap?
- Which apps are consuming the most resources?
- Has the Mac been under load recently?

## Technical direction

Use:

- Swift
- SwiftUI
- Native macOS APIs wherever practical
- Swift Charts for graphs/history
- A modular architecture
- No Electron
- No browser wrapper
- No unnecessary third-party dependencies

Target modern macOS versions unless the repository already defines a deployment target.

## Important architecture rule

Keep these concerns separate:

1. Metric collection
2. Metric storage/history
3. Interpretation / health scoring
4. Presentation / UI

Do NOT mix raw metric collection code with human-readable health judgments.

For example:

Raw metric:
`swapUsedBytes = 1_800_000_000`

Interpretation:
`Swap is being used, but memory pressure is currently normal.`

UI:
`Your Mac is managing memory normally.`

## Accuracy rule

Do NOT treat "low free RAM" by itself as a problem.

macOS intentionally uses unused memory for caches. Memory health should consider signals such as:

- memory pressure
- swap usage and swap growth
- compressed memory
- available/reclaimable memory where obtainable
- sustained pressure over time

Avoid scary or misleading wording.

## UX direction

The default experience should be designed for normal users.

Prefer:

- Green / amber / red or equivalent health states
- Plain English
- Short explanations
- Helpful context
- Clear "what is causing this?" summaries
- Progressive disclosure

Avoid making the main dashboard look like Activity Monitor.

An Advanced screen may expose detailed values for technical users.

## Suggested V1 screens

### Overview
- Overall Mac health
- CPU summary
- Memory summary
- Top resource-consuming apps
- Disk activity
- Network activity
- Short recent-history charts

### Apps / Processes
- Human-readable process/app names
- CPU
- Memory
- Energy-related information if practical
- Sort/filter
- Highlight unusually heavy apps

### History
- Recent CPU
- Memory pressure
- Swap
- Disk activity
- Network activity

Suggested periods:
- 5 minutes
- 30 minutes
- 2 hours

### Advanced
- Raw-ish system values
- Detailed process table
- Technical labels and explanations

### Settings
- Refresh frequency
- Start at login if feasible
- Menu bar behavior if implemented
- History retention

## Engineering expectations

- Inspect the existing repository before making changes.
- Preserve working code.
- Do not invent APIs that do not exist.
- If an Apple API cannot provide a metric directly, use an appropriate lower-level macOS API or command-line/system interface only when justified.
- Clearly document any permissions or sandbox limitations.
- Avoid polling more frequently than necessary.
- The monitoring app itself must remain lightweight.
- Add tests where logic is deterministic.
- Prefer small focused types and files.
- Keep build warnings at zero where practical.

## Work style

Before editing:
1. Inspect the repository.
2. Briefly state what you found.
3. Identify the files/components you will change.
4. Implement the requested task.
5. Build/test where possible.
6. Summarize exactly what changed and any remaining limitations.

Do not redesign unrelated parts of the project.
