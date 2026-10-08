# Shared Project Context — Wren

## What this project is

Wren is a calm, nature-inspired macOS activity monitor that explains what the machine is doing in plain language. Like the bird it is named after — small, quiet, with an outsized song — it watches silently and speaks up only when something matters.

Full vision and design direction live in [`project-wren-idea.md`](project-wren-idea.md).

## Product goal

Build a lightweight native macOS app that a user can download and install as a `.dmg`, which collects useful Mac system metrics and presents them in a way that is *reassuring and readable* — honest about what the machine is actually doing, calm about what is normal, and clear about what is not.

Wren has no mascot, no characters, and no fiction layer. Its personality is in the writing: plain, warm, occasionally wry, never dramatic. The app observes; it does not perform.

## Design direction (2026-10-08 decision)

Wren replaces the earlier flashy, game-inspired concept. The direction is calm, light, and nature-inspired — a small bird watching your Mac.

- **Paper & Panel** is the visual language: warm paper surfaces, soft ink, quiet panels, typography that reads like a well-set page rather than a dashboard.
- Stats are front and center. Everything decorative earns its place or goes.
- Motion is gentle and rare: values ease in, charts drift, transitions are soft. Nothing bounces, pops, flashes, or demands attention. Respect `accessibilityReduceMotion`.
- No mascot, no cast, no speech bubbles, no stage strip. Commentary is carried by the writing itself.
- The tone rule: calm about what is normal, plain about what is worth knowing, never alarming for effect. The humor, if any, is dry and in the margins.
- Restraint is the identity. The interesting part of Wren is that nothing is shouting.

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

Raw metrics never mix with human-readable judgments. The explanation/glossary layer turns interpretation signals into plain language — it never invents its own reading of the machine.

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

The tone is calm; the facts are exact. Avoid scary or misleading wording, and never soften a real problem into false comfort — the numbers must never lie.

## Screens

The tabs are the backbone: Overview, Apps, Energy, History, Wiki, Advanced, and Settings (see the README features section). The Wiki is the home of "what is this process?" answers and is linked from process rows ("What is this?"). All screens follow the Paper & Panel language.

## Engineering expectations

- Inspect the existing repository before making changes.
- Preserve working code.
- Do not invent APIs that do not exist.
- If an Apple API cannot provide a metric directly, use an appropriate lower-level macOS API or command-line/system interface only when justified.
- Clearly document any permissions or sandbox limitations.
- Avoid polling more frequently than necessary.
- The monitoring app itself must remain lightweight — calm visuals must not make the app heavy.
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
