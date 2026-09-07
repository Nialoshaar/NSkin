# Optimization Pass 1 validation

## Automated checks

From the repository root, run `lua Tests/OptimizationPass1.lua` with Lua 5.4.
The installed Lua Language Server executable also accepts that script directly.
The test is not loaded by the addon TOC.

The harness loads the real component core and Collections module with mocked WoW
surfaces. It verifies canonical registration identity, preset/setup reuse,
updated/removed skin options, targeted element edits and resets, appearance-only
placement avoidance, broad fallback routing, current-page lifecycle work, and late
adapter initialization. It does not prove client rendering or taint behavior.

Lua Language Server error diagnostics and `git diff --check` also pass.

## Client validation — pending

Use the same client, profile, enabled addons, and exact procedure as the existing
baseline captures. No before/after Perfy numbers were collected by this pass.

After `/reload`, test Mounts, Pets, Toys, Heirlooms, Appearances, and Campsites:

- Open/close repeatedly and switch all tabs repeatedly.
- Exercise search/filter controls and pagination.
- Verify ToyBox and Heirloom generated buttons after content updates.
- Compare appearance with the baseline, including selected top/bottom tabs.

In Skinning Mode, select Collections elements and change border, background,
font, and size. Reset individual properties, then Reset element customizations.
Move elements, reload, and verify saved placement.

In Options, change and reset a Collections element override, a Collections
window override, and a global appearance option.

Repeat the existing comparable captures without changing the procedure:

- Collections reopen ×10
- Skinning Mode interaction
- Options UI interaction

Inspect reduction in `SkinCollectionsWindow`, `ApplyCollectionsSkin`, and
`RegisterTypedElement` work during reopens. Known typed element edits should
refresh the component without cross-module `RefreshAppearance` branches.
Verify idle remains effectively zero. No numerical improvement is claimed until
these comparable captures are available.

## Conservative fallbacks

`RefreshAppearance()` without a descriptor preserves full refresh semantics.
Element/window setters carry scope, ID, style/path information where available;
global setters carry global scope and style/path. Cache invalidation remains broad.

Canonical typed registrations and controller refresh contracts use the targeted path. Unresolved elements,
custom skin adapters, mismatched styles/targets, window/global changes, and
elements or modules with `requiresStructuralRefresh = true` use the full path.
Controller-owned search/pagination elements use their scoped appearance/layout
contracts. Targeted refresh does not rebuild Options
chrome; Skinning Mode updates the affected overlay and selected inspector.

Persistent Collections controls register during adapter initialization. Controls
whose layout/controllers are not ready are retried when that adapter is active.
Full appearance refresh still covers all available adapters. Existing generated
item hooks remain installed, and no polling or additional frame scanning is used.
