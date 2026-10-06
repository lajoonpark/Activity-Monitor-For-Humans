# Shared Project Context — TIM (The Ironic Monitor)

## What this project is

TIM ("The Ironic Monitor") is a flashy, game-inspired macOS activity monitor with a personality. It is a fork of Activity-Monitor-For-Humans ("MacExplainer"): the metrics engine is reused as-is, and the personality/presentation layer is the new work.

Full vision and characters live in [`project-tim-idea.md`](project-tim-idea.md).

## Product goal

Build a lightweight native macOS app that a user can download and install as a `.dmg`, which collects useful Mac system metrics and presents them in a way that is *fun* — satisfying enough that you could sit there clicking, scrolling, and moving the cursor around without getting bored — while remaining accurate and honest about what the machine is actually doing.

Tim Howard, an animated stick man, is the face of the app. He works at TIM compiling data and keeping the animations running. He is a little bored and tired of his job. His dream is to move to Italy and get a pay raise from his boss, Jimmy "the boss" Nelson — a grumpy man with a soft side who has never given him one in 60 years. Tim's coworkers make fun of him because his name is Tim and he works at TIM.

Other characters (Jimmy, coworkers) are **never shown on screen**. When they speak, their speech bubbles come in from the side of the window.

## Design direction (2026-10-07 decision)

Tim is an animated **overlay on a normal stats UI**, not a full scene where the metrics are props. Stats stay front and center; the personality is commentary.

- A persistent "stage strip" (bottom or side of the window) where Tim walks in, idles, works, and reacts to what the machine is doing ("CPU at 90%... this is fine.").
- Off-screen conversations with Jimmy and coworkers arrive as speech bubbles poking in from the window edge.
- Everything should have "juice": numbers that pop, hover/click feedback, satisfying transitions. Lean into video-game feel and indie-solo-dev charm.
- Lots of easter eggs (invent them as we go).
- The app must not become a toy that hides the data — the point is still to know what your Mac is doing.

The Paper & Panel design language from the parent project is expected to give way to something flashier; that direction is still to be defined.

## Technical direction

Use:

- Swift
- SwiftUI
- Native macOS APIs wherever practical
- Swift Charts for graphs/history (with more visual juice than stock charts where practical)
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
5. Tim / personality layer (reacts to metrics and interpretation signals; never computes them)

Raw metrics never mix with human-readable judgments, and Tim's lines are driven by the same signals the UI uses — he never invents his own reading of the machine.

For example:

Raw metric:
`swapUsedBytes = 1_800_000_000`

Interpretation:
`Swap is being used, but memory pressure is currently normal.`

UI:
`Your Mac is managing memory normally.`

Tim:
`*sigh* swap again. it's fine. it's always fine.`

## Accuracy rule

Do NOT treat "low free RAM" by itself as a problem.

macOS intentionally uses unused memory for caches. Memory health should consider signals such as:

- memory pressure
- swap usage and swap growth
- compressed memory
- available/reclaimable memory where obtainable
- sustained pressure over time

The humor is in the presentation, not the facts. Avoid scary or misleading wording; Tim can be dramatic, but the numbers must never lie.

## Screens

The existing stat tabs remain the backbone (Overview, Apps, Energy, History, Advanced, Settings — see the README architecture section), reskinned toward the new flashy direction. The Tim stage strip is the new persistent element across screens. The landing page (website) is narrated by Tim walking on screen, followed by speech-bubble exposition with occasional Jimmy interjections.

## Engineering expectations

- Inspect the existing repository before making changes.
- Preserve working code.
- Do not invent APIs that do not exist.
- If an Apple API cannot provide a metric directly, use an appropriate lower-level macOS API or command-line/system interface only when justified.
- Clearly document any permissions or sandbox limitations.
- Avoid polling more frequently than necessary.
- The monitoring app itself must remain lightweight — flashy visuals must not make the app heavy.
- Add tests where logic is deterministic (animation and dialogue sequencing should also be testable at the state-machine level).
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
