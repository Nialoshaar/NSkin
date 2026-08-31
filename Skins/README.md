# Skins

One file per visual skin. A skin changes the presentation of an existing frame
without owning the underlying gameplay behavior.

NSkin skins only explicitly registered game-window components. It does not
scan or modify unrelated Objective Tracker, Scenario, widget, tooltip, or
other global progress bars.

## Empty-profile invariant

With no saved NSkin override, a Blizzard-owned frame keeps its live width,
height, anchors, spacing, text sizes, icon disposition, and other geometry.
Shared components capture any Blizzard state they may later change before the
first skin pass. They restore that captured state when an override is absent
or reset. Only an explicit profile override may change Blizzard geometry.

NSkin may still replace visual artwork, backgrounds, borders, textures,
colors, fonts, and icon cropping. Fixed dimensions are reserved for NSkin-owned
interfaces such as the options window, Docked Window, editor grid, and controls.

Load-on-demand windows register through `NSkin:RegisterWindowSkin`. Their
`Initialize` method must return `true` only after all required Blizzard objects
were found and the skin was installed; it returns `false` when initialization
should remain retryable. The registry makes up to three zero-delay deferred
retries, then stops without leaving an event or update loop active.

Per-frame state belongs in a named `NSkin:GetSkinData` scope such as
`"spellBook"`. Shared textures and borders should use the canonical primitive
lookups in `NSkin_Components.lua` instead of storing a second reference.
