# Modules

One file per behavior-oriented feature. A module owns new controls, state, or a
replacement implementation rather than only restyling an existing frame.

Examples: vehicle/override bar and custom class-resource bars.

New module files must also be added to `NialoSkin.toc` after their dependencies.

Every entry in `NSkin.moduleDefinitions` automatically receives an options
navigation tab and enable button. Use `optionsGroup` and `optionsOrder` there to
place it. If a module has settings, its options file only needs to register the
module key and builder with `NSkin:RegisterOptionsPage`; modules without a
builder receive a lightweight informational page automatically.
