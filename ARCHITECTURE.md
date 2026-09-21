# NSkin Architecture

This document defines the stable architectural rules for NSkin.

Codex should read this file before making substantial changes to shared components, Skinning Mode, window adapters, reset behavior, option inheritance, or performance-sensitive refresh paths.

Task-specific prompts may add temporary requirements, but they should not silently contradict this document. If a task genuinely requires changing one of these architectural rules, treat that as an architectural refactor and update this file as part of the change.

---

# 1. Project Scope

NSkin is an advanced standalone skinning addon for Blizzard UI windows.

Its scope is visual skinning and layout of Blizzard windows such as:

- Spellbook
- Collections
- Adventure Guide
- Professions
- Character-related windows
- other Blizzard panels and popups

NSkin is **not** intended to become a general combat UI replacement.

Do not expand the project into unrelated systems such as:

- unit frames
- nameplates
- combat rotation helpers
- combat automation
- unrelated gameplay features

The addon should remain centered on skinning and editing Blizzard UI presentation.

---

# 2. Core Architectural Rule

The central rule is:

> Registration defines what an element is and where it belongs.  
> Component type defines how it is skinned and what options it exposes.

Window-specific files should describe Blizzard structure and semantic membership.

Shared component files should define reusable visual behavior.

The same shared component should behave consistently everywhere it is registered.

---

# 3. Canonical Shared Components

Each shared component type should have one canonical implementation for:

- skin behavior
- appearance schema
- docked options
- reset behavior
- inheritance behavior
- common lifecycle handling

Examples include:

```text
WINDOW
WINDOW_HEADER
WINDOW_HEADER_CONTROLS
TAB_GROUP
SIDE_TAB
BUTTON
ACTION_BUTTON
CHECKBOX
DROPDOWN
SLIDER
NAVIGATION_BAR
EDIT_BOX
SEARCH_GROUP
SEARCH_BOX
PAGINATION_GROUP
PAGINATION_CHILD
PROGRESS_BAR
ICON
SCROLLBAR
SECTION_HEADER
SECTION_CARD
COLUMN_HEADER
ROW
SECTION_ROW
TEXT
```

Do not create page-specific copies of shared appearance logic.

For example, there should be one canonical shared `TEXT` appearance/options implementation.

All relevant text instances should reuse it:

```text
standalone TEXT
checkbox label TEXT
icon-associated TEXT
container child TEXT
row child TEXT
generated TEXT
```

Likewise, CHECKBOX, ICON, EDIT_BOX, ROW, and other shared types should each have one canonical shared implementation.

A new option added to a shared component should normally become available everywhere that component is used without modifying individual window files.

`BUTTON` and `ACTION_BUTTON` are visually related but semantically distinct:

```text
BUTTON
= secondary, utility, navigation, cancel, close, or non-commit action

ACTION_BUTTON
= primary operation/commit action for the current panel or workflow
```

Examples of `ACTION_BUTTON` include actions such as Create, Craft, Apply, Upgrade,
Accept, Send, Enter, Place Order, or Train when that control performs the panel's
primary operation. Do not classify a primary commit action as `BUTTON` merely
because it currently shares the same visual primitive.

---

# 4. Shared Options vs Window Adapters

Shared component option definitions belong in the shared component-options layer.

Window adapters should not reconstruct option panels.

A window adapter may provide:

- canonical ID
- target frame/region
- window/scope ID
- semantic label
- lifecycle provider
- exceptional Blizzard-state mapping
- composition membership
- container membership
- audited native decoration regions
- specific reset/lifecycle metadata when genuinely necessary

A window adapter should not normally provide:

- duplicated text controls
- duplicated icon controls
- custom checkbox option schemas
- custom generic hit-testing logic
- custom generic editor-tab construction
- custom generic bounds aggregation

If multiple windows need the same visual/editor behavior, move it into the shared component/composition layer.

A window adapter may compose or adapt shared component appearance behavior for
a Blizzard control whose state or geometry does not fit a canonical component
contract. Such a specialized adapter must preserve Blizzard semantics and
should not weaken or broaden a generic shared component contract merely to
support one exceptional control.

---

# 5. Appearance Inheritance

Appearance should resolve through the established hierarchy:

```text
NSkin defaults
→ global shared component type
→ window/scope override
→ individual element override
```

Lower-level overrides should remain sparse.

Do not create another hidden appearance tier for compositions or containers.

A composition may group components for editing, but it does not own a separate appearance schema.

---

# 6. Composition Is Separate From Components

NSkin distinguishes visual components from logical composition.

```text
Component
= visual behavior and canonical options

Composition
= structural relationship between components

Window adapter
= declares semantic grouping when that knowledge is window-specific
```

Do not create new visual component types merely because multiple canonical components appear together.

Examples:

```text
CHECKBOX + TEXT
→ composition of CHECKBOX and TEXT

ICON + TEXT
→ composition of ICON and TEXT

Crafting Details
→ semantic container declared by Professions
```

A composition should reuse canonical shared component options rather than redefine them.

Distinguish a component variation from a composition:

```text
Component variation
= the same semantic control with optional internal presentation/children

Composition
= multiple canonical semantic components combined into one logical editor control
```

Examples:

```text
EDIT_BOX with decrement/increment buttons
→ EDIT_BOX variation

CHECKBOX + TEXT
→ COMPOSITE

ICON + TEXT
→ COMPOSITE
```

Do not promote every control with multiple child regions into a Composite.

---

# 7. Structural Editor Modes

The composition/editor architecture uses three structural modes:

```text
STANDALONE
COMPOSITE
CONTAINER
```

These modes describe structure and ownership.

They must remain separate from any future Skinning Mode input policy.

Do not infer structural mode from arbitrary child count.

---

## 7.1 STANDALONE

A Standalone element is one independently edited component.

Typical behavior:

```text
selection = element
highlight = element bounds
movement = element's normal movement behavior
dock = canonical options for that component
```

---

## 7.2 COMPOSITE

A Composite represents several canonical components that together form one logical UI control.

Example:

```text
checkbox + attached label
```

Structural behavior:

```text
one logical Skinning Mode selection
members are not independently selectable
one movement owner
combined visible bounds
canonical options from member component types
```

The composition itself must not own duplicated visual options.

Composite members must retain canonical component identity, appearance
resolution, and reset ownership, but a secondary member does not need to exist
as an independently selectable Skinning Mode element merely to participate in
the Composite.

This differs from Container children, which remain independently addressable
canonical editor elements even when the current selection policy chooses not to
expose them directly.

For a primary + secondary composite, the dock should normally present:

```text
primary component options inline
secondary component options in tabs
```

Example:

```text
CHECKBOX + TEXT

primary = CHECKBOX
secondary = TEXT
movement owner = checkbox
```

Dock conceptually:

```text
Customize

canonical CHECKBOX controls

[Text]
    canonical TEXT controls
```

The checkbox+text composition should not create:

```text
CHECKBOX_TEXT
CHECKBOX_LABEL
CHECKBOX_COMBO
```

as visual component types.

A symbolic composition identifier such as `CHECKBOX_WITH_TEXT` is acceptable only if it clearly belongs to composition metadata rather than the visual component registry.

---

## 7.3 CONTAINER

A Container groups semantically distinct child components.

Example:

```text
Crafting Details
```

Structural behavior:

```text
container owns movement
children remain genuine canonical component registrations
children retain stable IDs and types
children retain canonical options
children are not independently movable
parent and child bounds remain addressable
```

The Container does not flatten its children into one visual component.

Children remain real components such as:

```text
TEXT
ICON
CHECKBOX
PROGRESS_BAR
ROW
EDIT_BOX
...
```

A Container may also contain a deliberately specialized window adapter when a
Blizzard control does not fit an existing canonical shared component contract.

The semantic membership of a Container belongs in the relevant window adapter.

The generic behavior of Containers belongs in the shared composition/editor layer.

---

# 8. Selection Policy Must Remain Replaceable

`STANDALONE`, `COMPOSITE`, and `CONTAINER` describe structural relationships.

They must not encode a specific future interaction model such as:

- modifier-key child selection
- drill-down selection
- double-click selection
- hierarchy browser selection

For a Container, preserve enough metadata for the Skinning Mode resolver to address either:

```text
container
or
child
```

without changing component registrations or ownership later.

The current development/debug selection policy may allow direct child selection because it is useful for validating child options and registrations.

That policy is not part of the definition of `CONTAINER`.

No component implementation or window adapter should assume that direct child
selection is permanent. Selection-policy decisions belong in Skinning Mode's
selection resolver.

Future Skinning Mode UX should be able to change selection policy without altering:

- canonical IDs
- shared component registrations
- composition membership
- appearance ownership
- movement ownership
- reset ownership

---

# 9. Movement Ownership

Movement and selection are separate concepts.

For a Composite:

```text
one explicit movement owner
all composite members follow through existing hierarchy/anchors
```

The declared `composition.movementOwner` is authoritative for baseline
capture, placement, reset, and Skinning Mode dragging. The element target
remains its registration and appearance target when it differs from the
movement owner.

Example:

```text
checkbox + label
movement owner = checkbox
label follows Blizzard's existing anchor
```

Do not create independent movement state for a child merely because it has its own appearance component.

For a Container:

```text
container = movable
children = non-movable
```

A child may remain selectable for debugging/editor purposes while still having no movement controls.

Movement suppression for Container children is an editor/composition-context rule, not a new subtype of the child component.

---

# 10. Anchoring Philosophy

Preserve Blizzard's existing anchor relationships whenever they already express the desired logical relationship.

The default NSkin presentation should preserve Blizzard's resolved geometry:
positions, sizes, relative anchors, and layout relationships remain Blizzard-owned
unless a specific NSkin layout option explicitly takes ownership of them.

Do not reproduce Blizzard placement with guessed or compensating offsets when the
original Blizzard anchors can simply be left intact. Replacing chrome, borders, or
background artwork is not by itself a reason to move Blizzard-owned content.

Do not build or apply custom anchors unnecessarily.

For example, Blizzard's standard checkbox template anchors its label to the checkbox. NSkin should preserve that relationship rather than introduce a new general anchor graph merely to group them.

When NSkin changes spacing or geometry:

- capture original Blizzard state before the first mutation
- mutate only what NSkin needs
- restore the exact original state on reset

Advanced anchor editing can be added later if needed.

Do not prematurely introduce:

- arbitrary anchor-target selection
- percentage positioning
- generalized constraint solvers
- complex anchor graphs

---

# 11. Reset and Original-State Ownership

Original Blizzard state must be captured before NSkin mutates a property.

Use first-write capture.

Never recapture an NSkin-modified value as the Blizzard baseline.

Reset should restore only properties NSkin owns.

Apply, refresh, and reset paths must be idempotent.

Prefer property-level ownership over broad state snapshots.

A reset should not revert unrelated Blizzard state or state owned by another shared component.

Examples:

```text
TEXT reset
→ TEXT-owned properties only

ICON reset
→ ICON-owned properties only

container movement reset
→ container movement only

composite reset
→ must not duplicate-reset member appearance
```

---

# 12. Stable Canonical IDs

Canonical IDs must remain stable across refactors.

Do not remove an explicit registration if doing so silently changes the canonical ID.

If registration strategy changes, preserve identity through either:

```text
natural ID continuity
or
explicit semantic mapping/aliasing
```

Do not optimize toward zero explicit registrations.

Stable identity is more important than minimizing registration declarations.

---

# 13. Explicit Registration Over Broad Discovery

Prefer explicit declarative registration for static controls.

Use targeted lifecycle providers/hooks for pooled or generated controls.

Avoid broad runtime discovery unless there is a strong architectural reason.

Discovery must not become a substitute for understanding Blizzard structure.

When Blizzard itself exposes a known repeated family through a stable template,
parent array, explicit provider, or equivalent semantic collection, a window
adapter may use one family helper to remove registration boilerplate.

A family helper does not determine logical identity by itself:

```text
persistent semantic members
→ one family helper may generate many stable canonical registrations

interchangeable pooled/recycled instances
→ one logical canonical registration may represent many runtime targets
```

Do not collapse persistent controls into one editor element merely because they
share a Blizzard template. Conversely, do not create persistent canonical IDs for
recycled frames merely because several physical frame instances exist.

For generated/pooled controls:

- enumerate the relevant active pool/provider
- use stable semantic IDs/slot logic
- refresh at the real lifecycle point
- do not use timers to compensate for missing lifecycle understanding

---

# 14. Generated and Pooled Controls

Pooled controls may be reused for different semantic content.

Do not assume a frame's previous state remains valid after reuse.

On relevant acquire/init/update lifecycle:

- re-resolve active visual regions
- re-resolve decorations
- re-resolve membership/state
- apply the canonical shared component behavior
- refresh only the relevant group/element

Do not use:

- `OnUpdate`
- polling
- delayed timers
- broad full-window re-apply

when an exact lifecycle hook exists.

A single logical editor registration may represent multiple equivalent runtime
instances of the same canonical component contract when those runtime instances
are interchangeable carriers of the same semantic element.

Typical examples include recycled ScrollBox rows or generated homogeneous entries:

```text
Loot item rows
Trainer rows
Death Recap rows
Mailbox rows
→ one logical registration per semantic row family
→ multiple active/recycled runtime targets
```

Do not assign canonical identity to the physical recycled frame or to a viewport
position such as `Row3` unless that position itself is genuinely the semantic
control being customized.

This differs from stable repeated controls such as fixed equipment slots. When
Blizzard exposes persistent semantic members through a stable array/template
family and NSkin intends them to be independently movable/customizable, a family
helper should generate stable individual canonical IDs for those members.

Grouped multiplicity is not a new visual component type and is not automatically
a `CONTAINER`.

---

# 15. ScrollBox Safety

Blizzard ScrollBoxes may exist before their View is ready.

A missing view means "not ready yet", not an error.

Do not blindly call raw enumeration methods when `GetView()` may be nil.

Use the shared readiness-aware ScrollBox enumeration helper.

Refresh later through the real Blizzard lifecycle rather than using timers or `pcall` as control flow.

---

# 16. ICON Contract

ICON is a canonical shared component.

General rules:

```text
Button/Frame
= logical interaction target

Texture
= presentation target

Border owner
= may differ from either
```

ICON may support shared controls such as:

- size
- crop
- zoom
- border
- shape (`square` by default, plus `circle`, `hexagon`, and `octagon`)
- quality presentation

Important invariants:

- crop changes presentation geometry without stretching
- zoom changes texcoords only
- changing icon presentation must not resize/move the parent Button unless explicitly intended
- visual skinning must not replace, cover, or steal mouse input from the Blizzard interaction target
- if Blizzard uses a Button/Frame hit rect or click script as the interaction owner, preserve that owner rather than duplicating its click behavior on an NSkin surface
- audited native decoration suppression must be targeted
- functional Blizzard overlays/state must be preserved
- direct `SkinIcon()` callers remain supported
- grouped/generated icon collections still use canonical ICON behavior
- icons that use Blizzard sprite-sheet coordinates may opt into
  `preserveTexCoords` while still using shared ICON geometry and lifecycle
- `size` is the canonical square dimension; legacy adapter-provided `width`
  and `height` remain supported for non-square layout contracts
- square borders use the shared pixel-border primitive; circle, hexagon, and
  octagon borders use a reusable NSkin-owned solid backing, masked to the
  selected shape and expanded in physical pixels behind the clipped texture
- native icon masks remain Blizzard-owned. An adapter may opt into suppressing
  an explicitly named native mask relationship; shared ICON records whether
  it removed that relationship and restores it on reset. NSkin removes only
  its own shape mask on reset or a switch back to square
- texture-backed ICON interaction may use a mouse-disabled presentation
  overlay while a Blizzard Button retains click and spell-cast ownership
- textured glow borders are shared NSkin-owned primitives; adapters decide
  their state and visibility

Clickable, empty, quality-bearing, disabled, popup-opening, or special-purpose icons should not become bespoke visual types merely because their behavior differs.

Special Blizzard slots such as enchant/salvage remain normal ICONs when their visual contract matches ICON.

SIDE_TAB remains the canonical registration for icon-based navigation tabs.
Its tab surface owns the background, border, hover, selected, and disabled
presentation; its icon uses the shared ICON skin internally without a separate
registration. Side tabs retain Blizzard icon anchors and size unless an ICON
appearance override explicitly changes them. The tab border is full by default;
an adapter may declare an `attachmentEdge` to leave that edge open.

---

# 17. ROW Contract

Shared column disposition is layout state, not an ICON appearance option. A
window adapter supplies allowed counts plus getter, setter, and refresh
callbacks to the shared controller. The controller captures Blizzard's first
value before changing it, stores only the explicit override, and restores the
captured value on reset. Existing module option keys may be retained for saved
profile compatibility.

Repeated `SECTION_HEADERS` instances use the shared header skin for text,
underline, optional placement offset, and audited native decoration. The
adapter supplies the pooled targets and their native fields; the shared skin
captures original text points and decoration state for reset. It maps
`text`/`textMode` to shared TEXT color handling and may accept a per-registration
`defaultTextSize` when no custom section-header size is selected.

Search accessories can omit the shared dropdown arrow, background, or border
without post-skin cleanup. In grouped mode, an unsaved placement restores the
accessory and primary Blizzard baselines in that order; custom placement
applies the primary first and then runs the adapter's grouped anchor callback.
When Blizzard anchors cross two controls that the adapter defines as separate
movement groups, the adapter may opt into using its declared window-relative
default placement as the reset baseline. That opt-in replaces the cross-group
anchor without changing either group's resolved default position; ordinary
movable elements continue to restore their captured Blizzard anchors.

ROW is used for tabular/data-record rows, often containing several cells or
fields. It owns row-level visual state such as:

- background
- border
- hover
- selected state

`showBackground = false` leaves ROW's border, hover, selected state, and
columns active while omitting its flat background.
`surfaceInset` controls the inset of the owned background and state overlays;
it defaults to 1, while 0 aligns those surfaces with the row border.

Cells inside a ROW remain canonical components such as:

- TEXT
- ICON

`SkinRow(row, { columns = { ... } })` may declare several typed columns.
Each column uses its existing shared component skin and resolves appearance
through the owning ROW element. The columns are presentation members of that
ROW, not separate canonical registrations or Skinning Mode elements. Repeated
applications must restore columns removed from the declaration, including for
recycled rows. The older `contentRegions` text path remains supported.

The row-level visual surface must not take interaction ownership away from
Blizzard child controls. If Blizzard intentionally makes a child button's hit
rectangle cover the row, keep that child as the click/tooltip interaction owner
and ensure NSkin-owned row surfaces do not intercept mouse input.

Multiple child regions of the same canonical type do not have to share one
individual appearance namespace when their semantics differ. For example, an
item-name `TEXT` and a quality-label `TEXT` may use separate logical registrations
if users need to customize them independently. They still use the same canonical
shared `TEXT` implementation; do not invent bespoke visual types.

ROW state may need to reassert child text presentation when Blizzard hover/selection logic restores native colors.

That does not make those texts a separate bespoke text type.

---

# 18. SECTION_ROW Contract

SECTION_ROW is used for lightweight hierarchical/list entries, usually
preserving Blizzard indentation and layout. It is borderless by default and
may own shared background, border, hover, and selected-state presentation.

Its text remains canonical TEXT behavior rather than a separate section-row
text type. SECTION_ROW may be collapsible or non-collapsible. When supplied,
an optional collapse/expand control retains Blizzard's logical state and
callbacks while SECTION_ROW skins only its visual interaction presentation.

Do not use SECTION_ROW for tabular/data-record rows that belong to ROW.

---

# 19. SECTION_CARD Contract

SECTION_CARD represents collapsible/category/header-like content rather than generic table rows.

It may own shared:

- background
- border
- hover
- selected/highlight behavior

Do not use SECTION_CARD as a generic substitute for ROW.

---

# 20. EDIT_BOX Contract

Spinner-style edit boxes are legitimate component variations.

For example:

```text
[-] [value] [+]
```

may still be one logical EDIT_BOX component variation.

This differs from compositions such as checkbox+text, where the members remain distinct canonical component types.

---

# 21. Popup Architecture

Reusable popup families belong in shared popup infrastructure when their visual/behavioral structure is genuinely shared.

A transient search preview with a Blizzard-owned ScrollBox or button pool may
compose the existing popup surface, ROW, ICON, and TEXT skins. Its adapter
provides active entries and hooks the list's real update lifecycle; NSkin
keeps click and selection ownership on Blizzard's result buttons.

Do not build one universal giant popup abstraction.

Prefer reusable families with explicit window-specific registration.

Examples may include:

- icon select popup
- confirmation dialogs
- color pickers
- profession-specific dialog families

---

# 22. Menu Architecture

Use generic Blizzard menu styling where Blizzard menu infrastructure is shared.

Avoid page-specific menu implementations when the underlying menu behavior is generic.

Window adapters may still provide exceptional menu anchors or state where required.

---

# 23. Window Chrome

Standard window chrome should use shared window/chrome components.

Standard chrome owns conventional inset presentation cleanup. It may suppress
named inset backgrounds, NineSlice containers, edges, and corners, but must not
hide the inset frame itself or its functional children.

Exceptional internal artwork suppression must remain explicit and audited.

Do not recursively hide all textures in a window.

Preserve functional Blizzard artwork/state.

---

# 24. Skinning Mode Principles

Skinning Mode should operate on semantic editor elements rather than arbitrary frame traversal.

The editor should distinguish:

```text
visual component identity
logical composition
movement ownership
selection policy
window/container membership
```

Do not couple these concepts unnecessarily.

For Composite elements:

- one selection
- combined bounds
- one movement owner
- canonical member options

For Container elements:

- container owns movement
- children remain canonical elements
- children remain non-movable
- parent/child relationship is preserved
- selection policy may evolve later

Keep the architecture "docked-window ready" without requiring final UX polish during foundational refactors.

---

# 25. Docked Window Principles

The docked window should stay compact and understandable.

Do not solve architecture problems by duplicating reduced option schemas.

Instead, reuse canonical component option groups and control their presentation.

General direction:

```text
Standalone
→ canonical component options

Composite
→ primary canonical options inline
→ secondary canonical components in tabs

Container
→ container-level controls when parent selected
→ canonical child controls when child selected
```

The dock renderer should reference existing shared option groups rather than reconstruct controls.

A window adapter or composition should declare component identity and option
presentation only. The dock should derive the actual controls from the
canonical shared component-options registry.

A composition may say:

```text
TEXT shown as secondary tab
```

but it must not redefine TEXT controls.

---

# 26. Window-Specific Containers

Semantic Containers belong in the window adapter because only that adapter understands the meaning of the Blizzard UI structure.

Example:

```text
Professions
→ declares which canonical child elements belong to Crafting Details
```

The shared composition layer defines what `CONTAINER` means and how its membership behaves.

This same pattern should apply to future complex groups in other windows.

---

# 27. Shared Intrinsic Compositions

Common intrinsic relationships should not be repeated in every window adapter.

Example:

```text
CHECKBOX with attached Blizzard FontString
→ shared checkbox/composition logic may register COMPOSITE
```

The shared checkbox registration may deterministically resolve known labels using explicit/known fields such as:

```text
definition.text
target.Text
target.text
```

Shared CHECKBOX skinning keeps Blizzard's hit rectangle intact and centers a
pixel-snapped visual square (14 by default, configurable with `visualSize`).
The owned background, border, checked mark, and hover surface follow that
square; an attached label may anchor to its right edge while its original
points remain available for reset.

Do not broadly scan arbitrary FontStrings.

This is not generic structural inference: the shared checkbox implementation knows its own intrinsic composition pattern.

---

# 28. Performance Rules

Perfy auditing and Optimization Passes 1–4 established the current performance baseline.

Do not add speculative optimization passes without a measured user-visible problem.

Preserve targeted invalidation.

Avoid:

- broad global refreshes for local changes
- full-window Apply calls for local appearance updates
- `OnUpdate` polling
- timers
- debounce layers
- deferred slider hacks

unless explicitly required by a demonstrated lifecycle constraint.

Composite member typography and geometry can change several times in one
frame during a single inspector edit. Their shared bounds notification may
coalesce those same-frame changes into one deferred notification; this is
limited to composite bounds and does not reapply a window or poll for changes.

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

---

# 29. Lifecycle Rules

Respect Blizzard's own lifecycle.

Do not change:

- visibility ownership
- interaction semantics
- security behavior
- protected state
- enabled/disabled state
- native functional overlays

unless the feature specifically requires it.

A safe-looking shared Blizzard template does not guarantee that every runtime
instance is writable. For secure-sensitive or transactional UI, runtime
accessibility is authoritative. If a target or child is forbidden/inaccessible,
skip the mutation and never attempt to bypass Blizzard protection.

Skinning should remain presentation-focused. NSkin-owned visual surfaces must not
become accidental mouse blockers or replacement interaction layers unless the
feature explicitly requires NSkin to own interaction.

Use targeted hooks rather than replacing Blizzard lifecycle logic.

---

# 30. Native Decoration Suppression

Only suppress native Blizzard visual regions that have been explicitly audited as decoration.

Do not hide unknown regions just because they are textures.

Preserve functional state regions such as:

- lock states
- input overlays
- quality/state indicators where still needed
- interaction feedback
- selection state required for Blizzard behavior

Use explicit `nativeDecorationRegions` or equivalent audited metadata when possible.

When NSkin owns hover presentation for a component:

- suppress native Blizzard hover artwork only after it has been explicitly identified as presentation-only
- preserve Blizzard's underlying interaction and state logic
- prefer explicit logical state providers such as `IsMouseOver()` over inferring hover from whether a Blizzard highlight texture is shown

---

# 31. Shared File Organization

Current shared component organization includes:

```text
Components/
    NSkin_ComponentsCore.lua
    NSkin_ComponentsWindows.lua
    NSkin_ComponentsInputs.lua
    NSkin_ComponentsNavigation.lua
    NSkin_ComponentsContent.lua
    NSkin_ComponentsPopup.lua
    NSkin_ComponentsMenus.lua
```

Composition should live in a dedicated shared layer when implemented, for example:

```text
Components/
    NSkin_ComponentsComposition.lua
```

Shared option files are organized separately under:

```text
Options/Components/
```

Keep visual implementation, editor composition, and option definitions clearly separated.

The shared composition implementation stores `composition` on the existing
Skinning Mode element: an explicit `mode`, Composite `members` with canonical
`kind` and primary/secondary `role`, or Container `children` containing canonical
element IDs. `movementOwner` is the registration's movement target. Container
children declare `compositionParentID` in their window adapter, including when
they register before the parent. Keep both sides of that explicit membership
consistent; optional runtime children need not exist yet.

`GetCompositionEditorOptions` derives member presentation from canonical editor
presets using the existing element appearance context. Composition has no separate
appearance state. Container child registration omits movement callbacks and
movement baseline capture. Skinning Mode owns hit priority and hover policy;
composition metadata contains no selection-policy flags.

---

# 32. Validation Rules for Codex

For normal NSkin implementation tasks:

1. Syntax-check changed Lua files.
2. Run:

```bash
git diff --check
```

3. Review the final diff for architectural regressions.
4. Do **not** run the repository `Tests` folder unless explicitly requested.
5. Do **not** commit unless explicitly requested.

The user runs the repository tests locally when needed.

---

# 33. Minimal Appearance Anchor Groups

An Anchor Group is an explicit, addon-authored editor relationship declared by
multiple registered elements with the same stable `anchorGroupID`. It is
orthogonal to `STANDALONE`, `COMPOSITE`, and `CONTAINER`: every member retains
its canonical ID, composition, container parent, lifecycle, runtime targets,
movement owner, and reset ownership.

The group may affect only:

- the Skinning Mode selection label and dock target;
- aggregation of unique canonical component option groups;
- the visual highlight, computed as the union of each visible member's own
  logical bounds;
- the individual appearance lookup key for canonical component types exposed
  by at least two group members.

Matching canonical types share the group ID as their sparse individual
appearance namespace. Non-matching types continue to use the canonical member
element ID. The existing default, global, window, and individual inheritance
resolver remains authoritative; an Anchor Group changes only the final
individual key. A deterministic migration may copy an existing member's real
local override into an empty group namespace, but must not materialize inherited
values or erase the original member override.

Anchor Groups are visual/editor-only in this phase. They do not own movement,
dragging, placement, Blizzard anchors, or `SetPoint()` calls, and they are not a
new component or composition mode.

---

# 34. Refactor Review Checklist

For any major shared-component/editor refactor, check for:

- duplicate canonical option schemas
- page-specific copies of shared behavior
- unstable canonical IDs
- broad discovery replacing explicit registration
- duplicate reset ownership
- baseline recapture after mutation
- window-specific generic editor logic
- compositions inventing visual types
- containers flattening real child registrations
- child movement leaking through container membership
- selection policy being baked into structural semantics
- broad refreshes
- timers or `OnUpdate`
- native Blizzard functional state being suppressed
- persistent controls incorrectly collapsed into grouped runtime multiplicity
- recycled runtime frames incorrectly given persistent per-frame IDs
- NSkin visual surfaces intercepting Blizzard-owned clicks/tooltips
- arbitrary geometry offsets replacing intact Blizzard anchor relationships
- same-type semantic fields unintentionally forced into one individual appearance namespace

---

# 35. Decision Rule for New Architecture

Before adding a new shared abstraction, ask:

> Would this rule or behavior be useful in multiple windows or multiple instances of the same component type?

If yes, it likely belongs in shared infrastructure.

If it describes the meaning of one Blizzard window's layout, it likely belongs in that window adapter.

If it is merely a temporary implementation detail for one task, it should normally remain in the task/code rather than this architecture document.

---

# 36. Updating This File

`ARCHITECTURE.md` should describe stable project-wide rules.

Update it when a major architectural decision changes, such as:

- component ownership
- composition semantics
- reset rules
- inheritance rules
- shared registration strategy
- editor architecture
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

# 37. Current Architectural Summary

```text
NSkin
│
├─ Shared Components
│   ├─ canonical visual behavior
│   ├─ canonical options
│   ├─ canonical reset ownership
│   └─ canonical inheritance
│
├─ Composition Layer
│   ├─ STANDALONE
│   ├─ COMPOSITE
│   └─ CONTAINER
│
├─ Skinning Mode
│   ├─ selection policy
│   ├─ virtual appearance Anchor Groups
│   ├─ highlights
│   ├─ movement
│   └─ dock presentation
│
└─ Window Adapters
    ├─ Blizzard targets
    ├─ canonical IDs
    ├─ lifecycle mapping
    ├─ semantic container membership
    └─ exceptional audited behavior
```

The main long-term principle is:

> Keep visual behavior canonical and shared, keep semantic grouping declarative, and keep editor interaction policy replaceable.
