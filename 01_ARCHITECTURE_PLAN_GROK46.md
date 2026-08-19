# Task 1 — Architecture and Technical Plan

**Kilo Mode:** Plan  
**Model:** Grok 4.6

Read `00_SHARED_CONTEXT.md` first.

Design the technical architecture for this native macOS system-monitoring application before implementation begins.

Your job is to create a concrete implementation plan suitable for handing to coding agents.

## Required output

Inspect the repository first, then produce a plan covering:

### 1. App architecture
Define the modules/types responsible for:
- system metric collection
- process/app metric collection
- recent-history storage
- health interpretation
- health scoring
- plain-English explanation generation
- SwiftUI presentation
- settings/preferences
- menu-bar integration if appropriate

### 2. macOS metric sources
For each proposed metric, identify the most reliable macOS-native mechanism/API.

Cover at minimum:
- total physical memory
- memory pressure or closest reliable equivalent
- used/compressed/wired memory if practical
- swap usage
- total CPU usage
- per-process CPU usage
- per-process memory usage
- disk read/write activity
- network send/receive activity
- uptime
- thermal state if realistically available
- battery/energy information on MacBooks if realistically available

Do not invent Apple APIs. Flag anything that requires lower-level Darwin APIs, Mach APIs, sysctl, proc APIs, command-line tools, entitlements, elevated permissions, or cannot be reliably accessed.

### 3. Data model
Propose concrete Swift structs/classes for:
- current snapshot
- per-process snapshot
- time-series history
- interpreted health state
- health reason / explanation

### 4. Sampling
Recommend:
- refresh interval
- history aggregation
- memory limits
- UI update strategy
- how to avoid the monitoring app becoming resource-heavy

### 5. Health model
Define a cautious initial health model for:
- Normal
- Moderate load
- High load
- Potential problem

Explain which metrics should influence each decision.

Do not classify high used RAM as unhealthy by itself.

### 6. Project structure
Recommend folders/files and responsibilities.

### 7. Development sequence
Break implementation into small sequential milestones that other agents can complete independently.

### 8. Risks
Identify:
- API limitations
- App Sandbox issues
- process visibility limitations
- code signing/notarization implications
- performance risks
- misleading metrics / interpretation risks

Do not implement large portions of the project in this task unless a tiny prototype is necessary to validate an API.
