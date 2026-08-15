# Nialo Skin

A small modular World of Warcraft addon for consistent Blizzard-interface skins.

## Layout

```text
NialoSkin/
|-- NialoSkin.toc              Addon metadata and load order
|-- Core.lua                   Namespace, modules, events, chat output
|-- Media.lua                  Shared textures and colors
|-- Skin.lua                   Shared pixel-border utility
|-- Options/
|   |-- NSkin_General_Options.lua  Shared `/nskin` window and progress-bar page
|   `-- Spellbook_Options.lua      Spellbook settings page
|-- Commands.lua               Central `/nskin` command router
|-- Media/Icon.tga             Addon-list icon
|-- Skins/
|   |-- BlizzardProgressBars.lua
|   `-- EncounterJournal.lua     Rectangular dungeon/raid instance cards
`-- Modules/                   Reserved for behavior-changing features
```

Put visual-only features in `Skins/` (for example Baganator or Objective Tracker
skins). Put features that add or substantially change behavior in `Modules/`
(for example a custom vehicle bar or resource bars). Register each feature with
`NSkin:NewModule("FeatureName")` so globals do not leak into the WoW UI namespace.

## Current feature

`BlizzardProgressBars` skins selected Blizzard status bars with a flat texture,
blue fill, dark background, one-pixel border, and centered label. It covers the
Objective Tracker and UIWidget containers, scenario/event header timers, and
World Map tooltip progress bars inherited from the original v1.0 prototype.

`EncounterJournal` removes the rounded border and glow from dungeon and raid
selection cards, slightly crops their artwork, and adds the same one-pixel black
border treatment used by the progress bars. Blizzard's normal, pushed,
highlight, and disabled texture slots are cleared with file ID `0`, preventing
the native rounded frame and glow from being selected by button-state changes.
It securely post-hooks Midnight's ScrollBox `Update` method and uses
`ForEachFrame` after Blizzard finishes each layout. Its
`OnInitializedFrame` callback handles cards acquired during deferred initial
layout. Page lifecycle triggers are coalesced into one next-frame refresh, so
late Blizzard atlas assignments are cleared without polling or traversal.
The `EncounterJournal.TabSet` EventRegistry callback is registered before the
Journal's load-on-demand addon opens, covering its first dungeon/raid tab.

Do not enable the old standalone `BlizzardProgressBarSkin` addon at the same
time. Both addons hook the same Blizzard widgets and will compete to restyle
them. Nialo Skin prints an in-game warning when it detects this conflict.

Progress bars are handled through specific Blizzard lifecycle hooks: the
status-bar and scenario-timer widget `Setup` mixins, each Objective Tracker's
`GetProgressBar`/`GetTimerBar`, and the tooltip progress/status-bar pool
functions. Their original foreground tint is kept; only the texture, dark
background, and one-pixel border are replaced. The addon does not enumerate
arbitrary frames or recursively walk UI trees.

All features are event/callback-driven. There are no `OnUpdate` polling loops.
The Encounter Journal uses its ScrollBox initialization/update callbacks and
the Journal's own tab/display lifecycle. Its card list is concealed during the
first layout and revealed by the first completed ScrollBox or coalesced
next-frame styling callback, preventing the native border from flashing without
polling rendered frames.

Commands:

- `/nskin` opens a scrollable progress-bar texture list. Selecting an entry
  updates visible bars immediately. Textures registered with LibSharedMedia are
  included automatically when that library is available. Reset restores the
  default NaowhGradient texture.
- `/nskin rescan` rescans supported progress-bar frames.
- `/nskin debug` prints hook state and the status bars styled this session.
- `/nskin journaldebug` prints Encounter Journal hook, state-texture, and region
  diagnostics for the currently visible dungeon or raid cards.

## Install for testing

Copy the `NialoSkin` directory into `_retail_/Interface/AddOns/`, then enable
**Nialo Skin** in the character-selection AddOns menu. Use `/reload` after code
changes.
