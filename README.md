# TIM — The Ironic Monitor

A flashy, game-inspired macOS activity monitor with a mascot who would rather be in Italy.

TIM started as a fork of [Activity-Monitor-For-Humans](https://github.com/lajoonpark/Activity-Monitor-For-Humans) ("MacExplainer"): a lightweight app that translates Activity Monitor-style system information into plain language — *"Is my Mac running normally?"*, *"What is making my Mac feel slow?"*, *"Is high RAM usage actually a problem?"*. TIM keeps that honest metrics engine and adds a personality layer on top: **Tim Howard**, an animated stick man who works at TIM, compiles the data, and makes sure the animations run smoothly. He is a little bored and tired of his job. His boss, Jimmy "the boss" Nelson, never appears on screen — nobody does except Tim. They speak through speech bubbles that poke in from the side of the window.

The vision, characters, and design decisions live in [`project-tim-idea.md`](project-tim-idea.md); the product/architecture rules live in [`00_SHARED_CONTEXT.md`](00_SHARED_CONTEXT.md).

## Features

The stat tabs from the parent app are the backbone:

- **Overview** — overall Mac health with a green/amber/red state, top apps by CPU, disk and network rates, battery, and short CPU/memory-pressure charts.
- **Apps** — sortable table of grouped apps (processes belonging to the same bundle are combined) with CPU %, memory, and a guarded **Quit** action for heavy apps.
- **Energy** — estimated energy use per app (watts), where macOS reports per-process energy. Includes a footnote when a Mac reports no energy data.
- **History** — CPU, memory pressure, swap, disk, and network history at 5-minute, 30-minute, or 2-hour windows.
- **Advanced** — raw-ish system values for technical users.
- **Settings** — sample interval (1/2/5 seconds), history retention, menu bar icon and menu bar metrics, and start-at-login.
- **Menu bar extra** — optional menu bar icon with a pop-up of current CPU/RAM readings.

The TIM layer is the new work (in progress):

- **Tim's stage strip** — a persistent corner of the window where Tim walks in, works, idles, and reacts to what the machine is doing.
- **Off-screen cast** — conversations with Jimmy and coworkers arrive as speech bubbles from the window edge.
- **Juice** — satisfying motion, numbers that pop, and easter eggs. Lots of easter eggs.

## Requirements

- macOS 14.0+
- Xcode (the project uses SwiftUI and `SWIFT_COMPILATION_MODE = wholemodule`)
- To build only, no code signing / Apple Developer account is needed.

> **Naming note:** source directories, the Xcode project, and the build scheme still use the `MacExplainer` name from the parent project. A rename to TIM is pending; commands below use the current names.

## Download / install

Grab the latest `MacExplainer-<version>-macOS[-arch].dmg` from the project's
GitHub **Releases** page, open it, and **drag the app into your Applications
folder**. Release DMGs are Apple Silicon (**arm64**) builds.

**Gatekeeper note:** the app is *ad-hoc signed* — the project doesn't use a paid
Apple Developer ID — so the first launch may say the developer "cannot be
verified". This is expected for an open-source, unsigned app. To open it
anyway:

- **Control-click** (right-click) the app → **Open** → **Open**, or
- **System Settings → Privacy & Security** → scroll to the bottom → **Open
  Anyway** → **Open**.

The DMG is an Apple Silicon (**arm64**) build. Run `make_release.sh` with
`ARCH=universal` if you need a combined Apple Silicon + Intel download.

## Build and run

Open `MacExplainer.xcodeproj` in Xcode and run the `MacExplainer` scheme, or:

```sh
xcodebuild -scheme MacExplainer -destination 'platform=macOS'
```

The app is built with no third-party dependencies and no code signing
pre-configured, so it runs locally from Xcode or a build folder without extra
setup.

## Building a release

To produce a local test DMG (ad-hoc signed) in `dist/`:

```sh
./scripts/make_release.sh              # universal (arm64 + x86_64)
ARCH=arm64 ./scripts/make_release.sh   # Apple Silicon only
```

This creates `dist/MacExplainer-<version>-macOS[-arch].dmg` plus a matching
`.dmg.sha256` checksum. To ship a release via CI, push a version tag and GitHub
Actions builds and attaches the DMG + checksum to a Release:

```sh
git tag v1.0.0
git push origin v1.0.0
```

(You can also run the **Release** workflow manually from the Actions tab with an
optional tag to attach the artifact to.)

## Tests

Unit tests cover grouping, history storage, energy/CPU deltas, formatters, health scoring, and explanation generation:

```sh
xcodebuild test -scheme MacExplainer -destination 'platform=macOS'
```

## Architecture

Repository layout follows a strict separation between concerns, per the project spec in [`00_SHARED_CONTEXT.md`](00_SHARED_CONTEXT.md):

| Layer | Location |
|---|---|
| Metric collection | `MacExplainer/Collection/` |
| Interpretation / health scoring | `MacExplainer/Interpretation/` |
| Storage / history | `MacExplainer/Storage/` |
| Presentation / UI | `MacExplainer/Presentation/` |
| Models, session, preferences | `MacExplainer/Models.swift`, `AppSession.swift`, `Settings/` |
| Tim / personality layer | *(planned)* `MacExplainer/Tim/` |

Key design points:

- Raw metrics never mix with human-readable health judgments; the interpreter emits signals (`cpuSustainedHigh`, `swapGrowing`, …) and the UI turns those into reassuring wording. Tim's reactions are driven by the same signals.
- Low free RAM is not treated as a problem on its own — health considers memory pressure, swap growth, and sustained load over time.
- Sampling runs on a dedicated utility `DispatchQueue` (`metrics.collection`); AppKit calls (e.g. app metadata) stay on the main actor and never block the sampler.
- "In use" RAM has one shared definition (`physical − free`) across the overview, menu bar label, and popup.
- macOS itself reports per-app energy only on some hardware; the Energy view degrades gracefully to "—" / 0 W elsewhere.
- Flashy visuals must not make the app heavy — the monitor itself stays lightweight.

## Repository map

```
MacExplainer/                 App sources (Swift, SwiftUI)
MacExplainerTests/           XCTest bundle with unit tests
MacExplainer.xcodeproj/      Xcode project
scripts/make_icon.swift      Generates the app icon artwork
scripts/make_release.sh      Builds the universal DMG release (local + CI)
.github/workflows/release.yml Tag-triggered CI that attaches the DMG to a Release
dist/                        Local release output (git-ignored)
00_SHARED_CONTEXT.md         Product/design/architecture rules for the app
project-tim-idea.md          TIM vision: mascot, cast, design direction
```
