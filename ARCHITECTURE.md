# NSkin Architecture

This document defines the stable architectural rules and target architecture for NSkin.

Codex should read this file before making substantial changes to shared components, Skinning Mode, window adapters, reset behavior, appearance inheritance, composition, or performance-sensitive refresh paths.

Task-specific prompts may add temporary requirements, but they must not silently contradict this document. If a task genuinely changes one of these rules, treat it as an architectural refactor and update this file.

The repository is currently migrating toward this architecture. Existing legacy component/grouping types may remain temporarily while callers are migrated. Their presence in the codebase does not make them part of the target architecture.

---

# 1. Project Scope

NSkin is an advanced standalone skinning addon for Blizzard UI windows.

Its scope is visual skinning and editable presentation of Blizzard windows such as:

- Spellbook
- Collections
- Adventure Guide
- Professions
- Character-related windows
- Group Finder
- other Blizzard panels and popups

NSkin is not intended to become a general combat UI replacement.

Do not expand the project into unrelated systems such as:

- unit frames
- nameplates
- combat rotation helpers
- combat automation
- unrelated gameplay features

The addon should remain centered on skinning and editing Blizzard UI presentation.

The default NSkin presentation should preserve Blizzard's layout. Position, size, anchors, visibility, interaction, protected behavior, enabled state, and functional overlays remain Blizzard-owned unless a specific NSkin feature explicitly takes ownership of them.

---

# 2. Core Architectural Model

The target architecture separates four questions:

```text
1. What reusable visual/control type is this?
   → Atomic Component

2. Which atomic elements permanently form one editable object?
   → COMPOSITE

3. Which independent editor elements structurally belong to a parent?
   → CONTAINER

4. Which independent editor elements may optionally be manipulated together?
   → EDITOR_GROUP
```

Movement is a separate editor capability. It does not define any of those concepts.

The central long-term rule is:

> Atomic components define reusable appearance and state. Composition defines relationships. Window files register Blizzard UI. Skinning Mode edits those structures.

Do not create a new component type merely because several controls appear together in one Blizzard layout.

---

# 3. Repository Ownership

The target ownership layout is:

```text
NSkin/
│
├─ Components/
│  ├─ canonical atomic component behavior
│  ├─ shared visual/state helpers
│  ├─ shared popup adapters
│  └─ shared menu/window presentation
│
├─ SkinningMode/
│  ├─ NSkin_SkinningMode.lua
│  ├─ NSkin_Composition.lua
│  └─ DockedWindow/
│     ├─ NSkin_DockedWindow.lua
│     └─ canonical option presentation files
│
├─ Windows/
│  └─ Blizzard window adapters
│
├─ Debug/
│  └─ Tests/
│
├─ NSkin_Menu.lua
├─ NSkin_Core.lua
├─ NSkin_Database.lua
└─ NSkin_Commands.lua
```

Responsibilities:

```text
Components/
= reusable visual/control behavior

SkinningMode/NSkin_Composition.lua
= structural/editor relationships

SkinningMode/NSkin_SkinningMode.lua
= selection, hover, highlights, input ownership, movement interaction,
  modal/occlusion handling

SkinningMode/DockedWindow/
= inspector UI and canonical option presentation

Windows/
= explicit knowledge of Blizzard windows, targets, semantic membership,
  lifecycle providers, and exceptional adapters

NSkin_Menu.lua
= main addon configuration UI

Debug/Tests/
= development validation files; not part of normal runtime architecture
```

The old `Skins/` name is replaced by `Windows/` because these files are Blizzard window adapters, not independent skinning systems.

---

# 4. Atomic Components

An atomic component represents a reusable visual/control contract.

A component type should exist because it has reusable appearance or state behavior, not because of its semantic role in one window.

Target atomic component families include concepts such as:

```text
TEXT
ICON
PROGRESS_BAR

BUTTON
ACTION_BUTTON
GLYPH_BUTTON
ICON_BUTTON
CHECKBOX
EDIT_BOX
DROPDOWN
SLIDER
SCROLLBAR
```

Window-level presentation may continue to use shared window/chrome infrastructure where appropriate.

Each canonical atomic component should have one shared implementation for:

- skin behavior
- appearance schema
- docked options
- original-state ownership
- reset behavior
- inheritance behavior
- common lifecycle handling

A new option added to a canonical component should normally become available everywhere that component is used without modifying individual window adapters.

Do not create page-specific copies of canonical appearance logic.

---

# 5. Component Identity vs Editor Identity

Appearance identity and editor identity are separate.

For example:

```text
COMPOSITE
├─ CHECKBOX
└─ TEXT
```

The Composite is one editor object, but CHECKBOX and TEXT retain their canonical atomic identities.

This distinction is fundamental:

```text
editor identity
≠
appearance identity
```

Composite membership must not flatten several atomic components into a bespoke visual component type.

Do not create types such as:

```text
CHECKBOX_TEXT
CHECKBOX_LABEL
ICON_TEXT_ROW
SEARCH_WITH_DROPDOWN
```

when normal atomic components plus composition can express the relationship.

---

# 6. STANDALONE

STANDALONE means one atomic component is exposed as one editor element.

Conceptually:

```text
STANDALONE
└─ TEXT
```

Typical behavior:

- one editor identity
- one canonical atomic appearance identity
- its own highlight
- its own safe movement contract when movement is supported
- canonical options for its component type

STANDALONE is a structural/editor relationship, not a component type.

---

# 7. COMPOSITE

A Composite represents multiple atomic components that permanently form one logical editor object.

Examples:

```text
checkbox option
├─ CHECKBOX
└─ TEXT

dungeon selector
├─ TEXT
└─ DROPDOWN

pagination
├─ GLYPH_BUTTON
├─ TEXT
└─ GLYPH_BUTTON

search control
├─ EDIT_BOX
└─ DROPDOWN
```

A Composite provides:

- one editor selection
- one outer highlight
- one Shift-drag movement operation
- combined bounds
- stable member identities
- canonical appearance for every member
- member-local X/Y
- generic member attach/detach
- dock aggregation of member options

The Composite itself does not duplicate member appearance schemas.

## 7.1 Composite Types

Every Composite has a type.

The initial/default type is:

```text
REGULAR
```

REGULAR should be sufficient for ordinary compositions.

Introduce a specialized Composite type only when a genuinely reusable behavior cannot be expressed through REGULAR plus normal member metadata. Do not use Composite types as semantic names for individual windows.

## 7.2 Composite Member Identity

Each member must retain:

- stable member identity
- canonical component kind
- appearance context
- reset ownership
- local placement state when NSkin owns it

A member's canonical appearance implementation remains authoritative.

## 7.3 Attached and Detached Members

Generic member state may be:

```text
ATTACHED
→ participates in Composite movement
→ represented as a Composite member/sub-highlight
→ not independently dragged as a separate editor object

DETACHED
→ no longer follows Composite-level movement
→ receives a valid independent placement contract
→ may become independently selectable
```

Detach must not blindly destroy Blizzard anchors. It changes participation in Composite placement/movement while preserving a safe independent placement contract.

## 7.4 Composite Skinning Mode Behavior

Target behavior:

```text
hover Composite
→ one outer highlight

select Composite
→ outer highlight
→ member sub-highlights

focus member in dock
→ stronger member sub-highlight

normal click on attached member
→ select Composite

Shift-drag
→ move Composite as a whole

member X/Y
→ edit member-local placement
```

Direct Shift-drag of attached members is not required. Member-local placement is initially controlled through the dock.

---

# 8. CONTAINER

A Container is a true structural parent whose children remain independently registered and independently editable.

Example:

```text
CONTAINER
├─ TEXT
├─ ICON
├─ COMPOSITE
└─ BUTTON
```

A Container is appropriate when the parent-child relationship is real and useful independently of movement.

Container children retain:

- their own canonical IDs
- their own editor identities
- their own atomic/Composite structure
- their own canonical options
- their own reset ownership

A Container does not flatten children into one component or one Composite.

Do not use Container merely because several controls should move together.

If several atomic members permanently form one editor object, use COMPOSITE.

If several independent editor objects should optionally be manipulated together, use EDITOR_GROUP.

Selection policy remains separate from the definition of Container. Skinning Mode may later change how parent/child selection is exposed without changing registrations or identities.

---

# 9. EDITOR_GROUP

EDITOR_GROUP is an optional virtual editor relationship over complete, independently editable elements.

Example:

```text
Navigation Entry A ─┐
Navigation Entry B ─┼─ EDITOR_GROUP: Left Navigation
Navigation Entry C ─┘
```

The members remain independently editable.

The Editor Group may provide:

- collective selection
- combined highlight/envelope
- collective movement
- a group label in Skinning Mode

The distinction is:

```text
COMPOSITE
A + B + C → one editor object

EDITOR_GROUP
A, B, C remain independent
+ optional GROUP(A, B, C)
```

EDITOR_GROUP should be used sparingly.

The current Anchor Group implementation is transitional architecture. During the refactor, its valid editor-only behavior should migrate toward EDITOR_GROUP rather than making Anchor Group a permanent independent architectural concept.

Appearance sharing must not be inherently coupled to Editor Group. If shared appearance across otherwise independent elements is needed, it should use a separate appearance relationship such as `appearanceGroupID` rather than redefining Editor Group.

---

# 10. Movement Is a Separate Capability

Movement is not a structural mode.

Do not define STANDALONE, COMPOSITE, CONTAINER, or EDITOR_GROUP by whether something moves.

Skinning Mode movement activation remains:

```text
normal click
→ selection

normal drag
→ selection-safe; no geometry mutation

Shift + drag
→ activate movement for the selected editor object
```

Movement requires a safe placement contract.

Preserve Blizzard anchor relationships whenever they already express the desired relationship. Do not recreate Blizzard layout with guessed offsets.

When NSkin takes ownership of placement:

- capture Blizzard state before first mutation
- mutate only the required anchors/offsets
- keep ownership explicit
- reset to the captured Blizzard baseline
- never accumulate offsets from an already NSkin-modified baseline

Movement availability and movement ownership must remain independent from selection policy.

---

# 11. Surface Capability

Surface is an optional appearance capability.

It is not:

- an atomic component type
- a composition mode
- a Container
- an Editor Group
- an editor identity by itself

Surface answers:

> What visual decoration surrounds or backs this owning element?

A Surface may provide shared behavior such as:

```text
Surface
├─ Background
│  ├─ Default / None / Color / Texture
│  ├─ color
│  ├─ opacity
│  ├─ texture / atlas / file
│  └─ optional crop/tiling where supported
│
├─ Border
│  ├─ mode
│  ├─ color
│  └─ size
│
└─ Padding
```

Surface may either skin an explicitly declared existing Blizzard visual surface or create NSkin-owned non-interactive decoration around the owner's bounds.

Surface must not own:

- selection
- movement
- children
- member anchors
- editor grouping
- semantic identity

NSkin-created Surface regions must not steal Blizzard clicks, tooltips, or hit regions.

## 11.1 Surface Eligibility and Defaults

Surface capability and Surface-default inheritance are separate policies.

Initial use is intended primarily for eligible standalone atomic elements.

For example:

```text
STANDALONE + TEXT
→ may expose Surface

global "standalone TEXT Surface" defaults
→ apply only to eligible standalone TEXT elements
```

A TEXT member inside a Composite still receives normal TEXT appearance defaults, but must not automatically receive standalone-TEXT Surface defaults.

The capability must remain generic enough that future architecture can allow:

```text
COMPOSITE + Surface
CONTAINER + Surface
WINDOW + Surface
```

where that makes sense, without causing those owners to inherit standalone-component Surface defaults.

---

# 12. Appearance Inheritance

Canonical component appearance resolves through the established hierarchy:

```text
NSkin defaults
→ global canonical component type
→ window/scope override
→ individual appearance identity override
```

Lower-level overrides should remain sparse.

Composition does not create a hidden appearance tier.

Composite members resolve appearance through their canonical component identities.

Surface defaults use their own eligibility/inheritance policy as described above; they must not blur structural relationships with appearance inheritance.

Editor grouping and appearance grouping are separate concerns.

---

# 13. Shared Options and Configuration UI

Canonical option definitions belong with shared component/capability infrastructure, not in individual window adapters.

The Docked Window should consume canonical option definitions rather than reconstruct reduced copies.

Conceptually:

```text
STANDALONE
→ canonical component options
→ eligible capabilities such as Surface

COMPOSITE
→ Composite structural options
→ canonical member option groups

CONTAINER
→ parent structural controls where relevant
→ independently addressable child options

EDITOR_GROUP
→ editor-group controls
→ member appearance remains independently canonical
```

The future main addon menu should reuse the same canonical schemas/contracts wherever possible.

Do not create one TEXT configuration implementation for Skinning Mode and another unrelated TEXT implementation for `/nskin`.

`NSkin_Menu.lua` is the root main-menu implementation.

`Options/NSkin_WindowsOptions.lua` remains transitional. Generic component/capability options should migrate to their canonical owners; genuinely window-specific options should remain owned by the relevant window/module architecture.

---

# 14. Window Adapters

Files under `Windows/` describe Blizzard UI structure and semantic knowledge.

A window adapter may provide:

- canonical ID
- Blizzard target frame/region
- window/scope ID
- semantic label
- atomic component kind
- composition membership
- Container membership
- Editor Group membership
- lifecycle provider
- exceptional Blizzard-state mapping
- audited native decoration regions
- specific reset/lifecycle metadata when genuinely necessary

A window adapter should not normally provide:

- duplicated TEXT/ICON/etc. appearance logic
- duplicated canonical option schemas
- generic Composite behavior
- generic Container behavior
- generic Editor Group behavior
- generic Skinning Mode hit-testing
- generic bounds aggregation
- generic Surface implementation

If several windows need the same visual/editor behavior, move it into shared infrastructure.

Window-specific exceptional adapters are allowed when a Blizzard control genuinely does not fit a canonical contract, but they must not weaken a shared contract merely to accommodate one exceptional control.

---

# 15. Explicit Registration and Runtime Families

Prefer explicit declarative registration for static Blizzard controls.

Do not optimize toward zero explicit registrations.

Stable canonical identity is more important than minimizing registration declarations.

Use targeted lifecycle providers for generated/pooled controls.

A shared family helper is appropriate when Blizzard exposes a known repeated family through a stable template, array, provider, or equivalent semantic collection.

Identity rules:

```text
persistent semantic members
→ may generate stable individual canonical registrations

interchangeable pooled/recycled frames
→ physical frame identity is not canonical identity
→ one logical registration may represent multiple runtime targets
```

Do not use broad runtime discovery as a substitute for understanding Blizzard structure.

---

# 16. Generated and Pooled Controls

Pooled controls may be reused for different semantic content.

On the relevant acquire/init/update lifecycle:

- re-resolve active presentation targets
- re-resolve audited decoration
- re-resolve semantic state/membership
- apply canonical shared behavior
- refresh only the relevant element/family

Do not use:

- `OnUpdate`
- polling
- delayed timers
- broad full-window reapply

when an exact Blizzard lifecycle hook exists.

A missing ScrollBox view means "not ready yet", not an error. Use readiness-aware enumeration and refresh through the real lifecycle.

For secure-sensitive or transactional UI, runtime accessibility is authoritative. If a target is forbidden or inaccessible, skip the mutation. Do not attempt to bypass Blizzard protection.

---

# 17. Stable IDs

Canonical IDs must remain stable across refactors.

Do not remove an explicit registration if doing so silently changes identity.

If registration strategy changes, preserve identity through:

```text
natural ID continuity
or
explicit semantic mapping/aliasing
```

Composite member IDs must also remain stable.

A physical recycled frame or viewport position must not become a persistent canonical ID unless that position is genuinely the semantic object being customized.

---

# 18. Reset and Original-State Ownership

Original Blizzard state must be captured before NSkin's first mutation of that property.

Use first-write capture.

Never recapture an NSkin-modified value as the Blizzard baseline.

Reset only properties NSkin owns.

Apply, refresh, and reset paths must be idempotent.

Prefer property-level ownership over broad state snapshots.

Examples:

```text
TEXT reset
→ TEXT-owned properties only

ICON reset
→ ICON-owned properties only

Surface reset
→ Surface-owned decoration only

Composite movement reset
→ Composite-owned placement only
→ must not duplicate-reset member appearance
```

When multiple shared systems touch one Blizzard object, their ownership boundaries must remain explicit.

---

# 19. Anchoring Philosophy

Preserve Blizzard's existing anchor relationships whenever they already express the desired logical relationship.

The default NSkin presentation should preserve Blizzard's resolved geometry:

- positions
- sizes
- relative anchors
- layout relationships

Replacing artwork, backgrounds, or borders is not by itself a reason to move Blizzard-owned content.

Do not prematurely introduce:

- arbitrary anchor-target selection
- percentage positioning
- generalized constraint solvers
- broad custom anchor graphs

When NSkin changes geometry, capture the original Blizzard state before mutation and restore exactly the properties NSkin owns.

---

# 20. Canonical Component Contracts

Detailed component behavior belongs in the relevant canonical component implementation, but several project-wide invariants apply.

## 20.1 TEXT

TEXT remains one canonical appearance contract wherever it is used.

Examples:

```text
standalone TEXT
Composite member TEXT
Container child TEXT
generated TEXT
```

Semantic context may give same-type TEXT members separate stable appearance identities when users need to customize them independently.

## 20.2 ICON

ICON separates logical interaction target from presentation texture.

General invariants:

- crop changes sampled texture coordinates without stretching the rendered icon
- zoom changes texcoords only
- presentation changes must not unexpectedly resize/move the parent interaction target
- shapes and borders remain shared ICON behavior
- Blizzard interaction/state ownership is preserved
- pooled ICON targets must release/reacquire runtime state safely

A special semantic role does not justify a new icon component type if the visual contract is still ICON.

## 20.3 Buttons

BUTTON and ACTION_BUTTON remain semantically distinct even when they share visual primitives.

```text
BUTTON
= secondary, utility, navigation, cancel, close, or non-commit action

ACTION_BUTTON
= primary operation/commit action for the current panel/workflow
```

GLYPH_BUTTON is appropriate for icon-only/procedural-glyph button presentation.

ICON_BUTTON may be used where an icon-bearing button has a genuinely reusable atomic visual/control contract.

## 20.4 EDIT_BOX Variations

Internal controls that are intrinsic to one semantic EDIT_BOX may remain an EDIT_BOX variation when they do not represent independently meaningful atomic members.

Do not turn every internal Blizzard region into a Composite.

---

# 21. Legacy Grouping Types

The following kinds of shared types are migration candidates rather than target canonical architecture:

```text
ROW
SECTION_ROW
PAGINATION_GROUP
PAGINATION_CHILD
SEARCH_GROUP
SEARCH_ACCESSORY
TAB_GROUP
SIDE_TAB
NAVIGATION_BAR
WINDOW_HEADER_CONTROLS
COLUMN_HEADER
SECTION_HEADER
SECTION_CARD
```

Their current implementations may remain temporarily while the refactor is in progress.

For each legacy type, ask:

> Can this be represented as atomic components plus COMPOSITE or CONTAINER?

If yes, migrate it and remove the grouping-style shared type when no callers remain.

Examples:

```text
row of several fields
→ usually REGULAR COMPOSITE of atomic members

pagination
→ REGULAR COMPOSITE of GLYPH_BUTTON + TEXT + GLYPH_BUTTON

search
→ REGULAR COMPOSITE of EDIT_BOX + DROPDOWN where appropriate

tab with text/icon
→ atomic button-like member(s) plus REGULAR COMPOSITE when needed

section/card with independently editable children
→ CONTAINER, optionally with Surface

card that is one logical editor object
→ COMPOSITE, optionally with Surface
```

Do not mechanically rename legacy grouping types into new component types.

---

# 22. Tabs, Navigation, and Breadcrumbs

TAB and SIDE_TAB should not exist merely as grouping concepts.

Text tabs and icon side tabs should reuse atomic button/icon-button behavior plus composition/orientation metadata where needed.

A breadcrumb bar should normally be a Composite of canonical buttons. Introduce a specialized atomic button contract only if the breadcrumb button itself has genuinely reusable visual/state behavior that normal BUTTON cannot express.

Navigation is semantic/layout context, not by itself a canonical visual component family.

This is why `Components/NSkin_ComponentsNavigation.lua` and its dock option counterpart are transitional files. Their useful atomic behavior should migrate to the appropriate canonical owners during later refactor parts.

---

# 23. Popup Architecture

Reusable popup families belong in shared popup adapter infrastructure when their Blizzard structure is genuinely shared.

Keep `Components/NSkin_ComponentsPopup.lua` as shared adapter infrastructure rather than creating a POPUP atomic component for every popup family.

Popup adapters should compose normal canonical components and capabilities.

Do not build one universal giant popup abstraction.

Examples of reusable popup families may include:

- icon selection popups
- equipment flyouts
- confirmation dialog families
- color picker families

Window-specific semantic registration remains in the relevant window adapter.

---

# 24. Menu Architecture

Use shared Blizzard menu styling where Blizzard menu infrastructure is shared.

Avoid page-specific menu implementations when the underlying menu behavior is generic.

Window adapters may still provide exceptional menu anchors/state where genuinely required.

---

# 25. Window Chrome

Standard window chrome should use shared window/chrome infrastructure.

Adjacent NSkin-owned visual edges should resolve from consistent physical-pixel geometry so borders/backgrounds do not expose seams or double-thickness rows at fractional coordinates.

Standard chrome may suppress explicitly audited Blizzard decoration but must not recursively hide arbitrary textures or functional children.

Preserve:

- interaction
- functional overlays
- state indicators
- protected behavior
- Blizzard-owned visibility semantics

Generic Surface behavior should eventually absorb generic background/border capability where appropriate without turning Window into a structural Container.

---

# 26. Skinning Mode

Skinning Mode operates on semantic editor elements rather than arbitrary frame traversal.

It owns:

- hover
- selection
- highlights
- input ownership
- Shift-drag activation
- modal/occlusion handling
- editor interaction policy

It must distinguish:

```text
atomic appearance identity
editor identity
composition relationship
movement ownership
selection policy
window/container membership
input ownership / occlusion
```

Do not couple these concepts unnecessarily.

Highlight presentation and input ownership are separate surfaces.

An editor element is interactive only when its underlying Blizzard element is the topmost valid UI target at the pointer. Modal UI and unrelated windows must win over Skinning Mode.

Use event/lifecycle-driven invalidation rather than `OnUpdate` polling for occlusion.

Selection policy must remain replaceable without changing canonical IDs, composition membership, appearance ownership, movement ownership, or reset ownership.

---

# 27. Docked Window

The Docked Window is the compact inspector for the selected editor object.

It should render canonical option groups rather than duplicate schemas.

Target presentation:

```text
STANDALONE
→ canonical atomic options
→ eligible capability options

COMPOSITE
→ structural/position controls
→ primary/member canonical options
→ member sections/tabs as appropriate
→ attach/detach
→ member-local X/Y

CONTAINER
→ parent structural controls
→ independently addressable children

EDITOR_GROUP
→ collective editor controls
→ independent member appearance remains canonical
```

A window adapter may declare identity and presentation metadata, but it must not reconstruct generic dock controls.

---

# 28. Main Addon Menu

`NSkin_Menu.lua` is the main `/nskin` configuration UI.

Long-term global settings should consume the same canonical component/capability contracts used by Skinning Mode.

For example, a future TEXT section may expose:

```text
TEXT
├─ font
├─ size
├─ color
├─ outline
└─ eligible standalone Surface defaults
```

The menu must not create a second independent implementation of canonical appearance behavior.

Window/module enablement and genuinely window-specific configuration remain separate from canonical component defaults.

---

# 29. Performance Rules

Optimization Passes 1–4 established the current performance baseline.

Do not add speculative optimization passes without a measured user-visible problem.

Preserve targeted invalidation.

Avoid:

- broad global refreshes for local changes
- full-window Apply calls for local appearance updates
- `OnUpdate` polling
- timers
- debounce layers
- deferred-slider workarounds

unless a demonstrated lifecycle constraint requires them.

Prefer:

```text
local change
→ local dependency refresh
```

rather than:

```text
local change
→ refresh entire addon/window
```

A narrowly scoped same-frame coalescing mechanism is acceptable only when it addresses a demonstrated local dependency such as Composite bounds and does not become general polling/debounce architecture.

---

# 30. Blizzard Lifecycle and Safety

Respect Blizzard's lifecycle and ownership.

Do not change unless explicitly required:

- visibility ownership
- interaction semantics
- security behavior
- protected state
- enabled/disabled state
- native functional overlays

NSkin-created visual regions must not become accidental mouse blockers.

Use targeted hooks rather than replacing Blizzard lifecycle logic.

Only suppress native Blizzard visual regions that have been explicitly audited as decoration.

Do not hide unknown regions merely because they are textures.

Preserve functional state such as:

- lock states
- input overlays
- quality/state indicators where needed
- interaction feedback
- selection state required by Blizzard behavior

---

# 31. Current Repository During Migration

After Part 1 of the architecture refactor, the repository is organized around the new ownership boundaries while some legacy implementation files remain temporarily:

```text
NSkin/
│
├─ Components/
│  ├─ NSkin_ComponentsCore.lua
│  ├─ NSkin_ComponentsWindows.lua
│  ├─ NSkin_ComponentsInputs.lua
│  ├─ NSkin_ComponentsNavigation.lua       # transitional
│  ├─ NSkin_ComponentsContent.lua          # transitional
│  ├─ NSkin_ComponentsPopup.lua
│  └─ NSkin_ComponentsMenus.lua
│
├─ SkinningMode/
│  ├─ NSkin_SkinningMode.lua
│  ├─ NSkin_Composition.lua
│  └─ DockedWindow/
│     ├─ NSkin_DockedWindow.lua
│     ├─ NSkin_ComponentCoreOptions.lua
│     ├─ NSkin_ComponentWindowsOptions.lua
│     ├─ NSkin_ComponentInputsOptions.lua
│     ├─ NSkin_ComponentNavigationOptions.lua  # transitional
│     ├─ NSkin_ComponentContentOptions.lua     # transitional
│     └─ NSkin_ComponentMenusOptions.lua
│
├─ Windows/
│  └─ NSkin_*.lua
│
├─ Options/
│  ├─ NSkin_WindowsOptions.lua             # transitional
│  └─ README.md
│
├─ Debug/
│  ├─ NSkin_AppearanceDebug.lua
│  ├─ NSkin_LFGQueuePopDebug.lua
│  ├─ NSkin_SkinningDebugInspector.lua
│  └─ Tests/
│
├─ Media/
├─ NSkin_Menu.lua
├─ NSkin_Core.lua
├─ NSkin_Database.lua
├─ NSkin_Commands.lua
└─ NSkin.toc
```

Do not treat a transitional file/type as permanent merely because it still exists after Part 1.

Later refactor parts should remove or rename transitional files only when their callers have been migrated and the replacement architecture is functional.

---

# 32. Refactor Sequence

The intended migration sequence is:

```text
Part 1
Architecture/worktree organization
        ↓
Part 2
Composition foundation
        ↓
Part 3
Skinning Mode + Composite behavior
        ↓
Part 4
Legacy grouping migration
        ↓
Part 5
Container + Editor Group cleanup
        ↓
Part 6
Surface + final legacy cleanup
```

Part 4 may be split into smaller implementation patches by family:

```text
rows/section structures
search/pagination
tabs
navigation/breadcrumbs
remaining grouping/card structures
```

Every intermediate patch should leave the addon in a usable/checkable state.

---

# 33. Validation Rules for Codex

For normal NSkin implementation tasks:

1. Fetch and inspect the exact current target-branch files.
2. If earlier local blobs were applied but not pushed, reconstruct that local state before generating the next patch.
3. Keep the requested scope as small as practical.
4. Syntax-check changed Lua files.
5. Run:

```bash
git diff --check
```

6. Inspect the final diff for architectural regressions.
7. Do not run the repository `Debug/Tests` files unless explicitly requested.
8. Do not commit or push unless explicitly requested.

Patch blobs must be generated from exact before/after files with an automatic diff, not handwritten patch hunks.

---

# 34. Refactor Review Checklist

For major shared-component/editor changes, check for:

- duplicate canonical option schemas
- page-specific copies of shared behavior
- unstable canonical IDs
- unstable Composite member IDs
- broad discovery replacing explicit registration
- duplicate reset ownership
- baseline recapture after mutation
- window-specific generic editor logic
- compositions inventing visual types
- Containers used merely as movement groups
- Editor Groups flattening independent elements
- appearance sharing coupled unnecessarily to Editor Group
- selection policy baked into structural semantics
- movement semantics baked into component identity
- Surface gaining structural/editor responsibilities
- standalone Surface defaults leaking into Composite/Container owners
- broad refreshes
- timers or `OnUpdate`
- native Blizzard functional state being suppressed
- persistent controls incorrectly collapsed into grouped runtime multiplicity
- recycled runtime frames incorrectly given persistent per-frame IDs
- NSkin visual surfaces intercepting Blizzard-owned clicks/tooltips
- arbitrary geometry offsets replacing intact Blizzard anchor relationships
- same-type semantic fields unintentionally forced into one appearance identity

---

# 35. Decision Rule for New Abstractions

Before adding a new shared abstraction, ask:

> Is this reusable visual/control behavior, a structural relationship, an editor relationship, or window-specific Blizzard knowledge?

Then place it accordingly:

```text
reusable visual/control behavior
→ Components/

relationship between atomic/editor elements
→ SkinningMode/NSkin_Composition.lua

selection/highlight/input/movement interaction
→ SkinningMode/NSkin_SkinningMode.lua

inspector presentation
→ SkinningMode/DockedWindow/

Blizzard window meaning/lifecycle
→ Windows/

global addon configuration UI
→ NSkin_Menu.lua
```

If a proposed component exists only because several controls happen to be grouped together, it is probably composition rather than a new component.

If a proposed Container exists only because independent elements should move together, it is probably an Editor Group.

If a proposed Surface starts owning children, selection, or movement, its responsibility is too broad.

---

# 36. Updating This File

`ARCHITECTURE.md` describes stable project-wide rules and the explicit target of an active architecture migration.

Update it when a major architectural decision changes, such as:

- component ownership
- composition semantics
- Surface semantics
- reset rules
- inheritance rules
- shared registration strategy
- editor architecture
- repository ownership boundaries
- project-wide performance/lifecycle rules

Do not update it for every:

- bug fix
- new window
- minor option
- local registration
- one-off Blizzard lifecycle workaround

A useful test is:

> Would Codex need to know this rule while working on an unrelated NSkin window?

If yes, it probably belongs here.

---

# 37. Target Architectural Summary

```text
NSkin
│
├─ Atomic Components
│  ├─ canonical appearance/state
│  ├─ canonical options
│  ├─ canonical reset ownership
│  └─ canonical inheritance
│
├─ Optional Appearance Capabilities
│  └─ Surface
│     ├─ background
│     ├─ border
│     └─ padding
│
├─ Composition
│  ├─ STANDALONE
│  ├─ COMPOSITE
│  │  └─ type: REGULAR by default
│  ├─ CONTAINER
│  └─ EDITOR_GROUP
│
├─ Skinning Mode
│  ├─ selection
│  ├─ hover/highlights
│  ├─ input ownership
│  ├─ Shift-drag movement
│  └─ modal/occlusion policy
│
├─ Docked Window
│  ├─ canonical option presentation
│  ├─ Composite member editing
│  └─ structural editor controls
│
├─ Window Adapters
│  ├─ Blizzard targets
│  ├─ canonical IDs
│  ├─ semantic relationships
│  ├─ lifecycle mapping
│  └─ exceptional audited behavior
│
└─ Main Menu
   └─ global configuration using canonical contracts
```

The long-term principle is:

> Atomic components define reusable appearance/state. Composition defines relationships. Window files register Blizzard UI. Skinning Mode edits those structures.
