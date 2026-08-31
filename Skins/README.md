# Skins

One file per visual skin. A skin changes the presentation of an existing frame
without owning the underlying gameplay behavior.

Examples: Blizzard progress bars, Objective Tracker, Baganator, character frame.

Load-on-demand windows register through `NSkin:RegisterWindowSkin`. Their
`Initialize` method must return `true` only after all required Blizzard objects
were found and the skin was installed; it returns `false` when initialization
should remain retryable. The registry makes up to three zero-delay deferred
retries, then stops without leaving an event or update loop active.

Per-frame state belongs in a named `NSkin:GetSkinData` scope such as
`"spellBook"`. Shared textures and borders should use the canonical primitive
lookups in `NSkin_Components.lua` instead of storing a second reference.
