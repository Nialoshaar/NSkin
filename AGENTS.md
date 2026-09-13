# NSkin Codex Instructions

NSkin is a standalone World of Warcraft addon focused on skinning and editing Blizzard UI windows.

## Read architecture first

Before making substantial changes to any of the following, read `ARCHITECTURE.md` in the repository root:

- shared components
- Skinning Mode
- composition/grouping
- shared option schemas
- reset/original-state handling
- appearance inheritance
- lifecycle/refresh architecture
- pooled/generated or repeated controls
- popup/menu infrastructure
- interaction/security-sensitive controls
- performance-sensitive code

Treat `ARCHITECTURE.md` as the project-wide architectural source of truth.

Task-specific instructions may add temporary requirements. Do not silently contradict `ARCHITECTURE.md`. If a task genuinely requires changing a stable architectural rule, treat it as an architectural refactor and update `ARCHITECTURE.md` as part of the change.

## Core working rules

- Prefer explicit declarative registration for static Blizzard controls.
- Use targeted lifecycle hooks/providers for pooled or generated controls.
- Reuse canonical shared component behavior and canonical shared option groups.
- Do not create page-specific copies of shared appearance logic when the behavior is reusable.
- Keep component behavior, composition semantics, and window-specific membership separate.
- Preserve stable canonical IDs across refactors.
- Capture original Blizzard state before first mutation and never recapture NSkin-mutated values as baseline.
- Reset only NSkin-owned properties.
- Preserve Blizzard visibility, interaction ownership, enabled/disabled state, protected/security behavior, functional state overlays, and default layout unless the task explicitly requires changing them.
- Do not let NSkin-owned visual surfaces block Blizzard clicks, tooltips, or hit regions.
- If a runtime target is forbidden/protected/inaccessible, skip it; never attempt to bypass Blizzard protection.
- Suppress only audited native decorative regions.
- Avoid broad discovery when the Blizzard structure can be explicitly understood.
- Avoid broad refreshes for local changes.
- Do not add `OnUpdate`, polling, timers, debounce layers, or full-window re-apply paths when a targeted lifecycle hook exists.
- Preserve the performance baseline established by Optimization Passes 1-4 unless profiling shows a real regression.

## Shared architecture expectations

Use the existing shared component/composition architecture rather than inventing one-off alternatives.

Examples:

- `ICON`: Button/Frame is the logical target; the actual Texture is the presentation target.
- `CHECKBOX + TEXT`: use canonical CHECKBOX + canonical TEXT through composition, not a bespoke visual component.
- spinner `EDIT_BOX`: `[-] [value] [+]` is one logical edit-box variation.
- For repeated, generated, pooled, or recycled controls, follow the identity/grouping rules in `ARCHITECTURE.md`; do not infer registration strategy from frame count alone.
- semantic container relationships belong in the relevant window adapter; generic container behavior belongs in the shared composition/editor layer.

When adding a new abstraction, ask whether it is reusable across multiple windows or multiple instances of the same component type. If yes, it likely belongs in shared infrastructure. If it only describes the meaning of one Blizzard window, keep it in that window adapter.

## Scope control

Do not expand NSkin into unrelated combat/UI systems such as:

- unit frames
- nameplates
- rotation helpers
- combat automation
- unrelated gameplay features

Keep changes focused on Blizzard window skinning and editor behavior.

Do not turn a local bug fix into a broad refactor unless the task explicitly requires it or the existing architecture cannot support a clean fix.

## Validation

For normal implementation tasks:

1. Syntax-check every changed Lua file.
2. Run `git diff --check`.
3. Review the final diff for unintended or architectural regressions.
4. Do **not** run the repository `Tests` folder unless explicitly requested; the user runs those tests locally.
5. Do **not** commit unless explicitly requested.

For major shared-component/editor refactors, additionally review for:

- duplicated canonical option schemas
- page-specific copies of shared behavior
- unstable canonical IDs
- duplicate reset ownership
- baseline recapture after mutation
- composition inventing new visual component types unnecessarily
- container children accidentally receiving movement ownership
- selection policy being baked into structural semantics
- broad refreshes or polling
- suppression of functional Blizzard state
- accidental changes to Blizzard interaction ownership or default geometry
- forbidden/protected runtime targets being mutated

## Task execution

Before coding:

1. Read the relevant parts of `ARCHITECTURE.md`.
2. Inspect the current implementation before assuming the prompt describes the latest code exactly.
3. Identify whether the task is:
   - a local window-adapter change,
   - a shared component change,
   - a composition/editor change,
   - or a true architectural refactor.
4. Prefer the smallest change that preserves the shared architecture.
5. For repeated/generated controls, interaction-sensitive controls, or layout changes, verify the relevant architectural rule in `ARCHITECTURE.md` before implementing.
6. If the task prompt conflicts with `ARCHITECTURE.md`, do not silently choose one; identify the conflict and treat it as an architectural change only if the task explicitly requires that.

At the end, report:

- files changed,
- what was implemented,
- any shared architecture changed or extended,
- validation results,
- any remaining limitation or follow-up that should be handled separately.
