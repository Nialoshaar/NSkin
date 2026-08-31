# Modules

One file per behavior-oriented feature. A module owns new controls, state, or a
replacement implementation rather than only restyling an existing frame.

Examples: vehicle/override bar and custom class-resource bars.

New module files must also be added to the addon's TOC manifest after their dependencies.

Every entry in `NSkin.moduleDefinitions` automatically receives an options
navigation tab and enable button. Use `optionsGroup` and `optionsOrder` there to
place it. If a module has settings, its options file only needs to register the
module key and builder with `NSkin:RegisterOptionsPage`; modules without a
builder receive a lightweight informational page automatically.
# Blizzard geometry baselines

Shared components must capture Blizzard-owned geometry through
`CaptureComponentBaseline` before changing it. Baselines are runtime-only and
must never be copied into `NSkinDB`. Optional geometry uses `nil` to preserve
Blizzard's value; saved numeric values are explicit overrides.

Window registrations may provide `canCaptureBaseline` and
`refreshBlizzardLayout` adapters when Blizzard finalizes or owns the layout.
Resetting an element removes its sparse overrides, restores its runtime
baseline, and reapplies NSkin styling. It does not unskin the Blizzard frame.
