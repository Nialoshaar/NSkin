# NSkin Architecture

This document defines the stable architectural rules and target architecture for NSkin.

Codex should read this file before making substantial changes to shared components, Skinning Mode, window adapters, reset behavior, appearance inheritance, composition, or performance-sensitive refresh paths.

Task-specific prompts may add temporary requirements, but they must not silently contradict this document. If a task genuinely changes one of these rules, treat it as an architectural refactor and update this file.

The repository may contain legacy component/grouping paths alongside this architecture while windows are progressively migrated. Legacy code may remain when it is stable and not blocking current work; its presence does not make it part of the target architecture. New work should prefer the target architecture and should not introduce new dependencies on superseded abstractions.

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

The target architecture separates visual primitives, intrinsic control machinery,
editable controls, and structural grouping:

```text
CONTENT
= swappable presentation owned by an Element or Composite
= semantic visual slots rendered through supported representations such as
  TEXT / ICON / GLYPH / TEXTURE / ATLAS

PART
= reusable intrinsic machinery owned by an Element
= TRACK / THUMB and future genuinely structural parts

ELEMENT
= the smallest independently meaningful editor object
= may own Surface + Parts + Content + runtime States

COMPOSITE
= one logical editor object built from members under lasting logical ownership

CONTAINER
= an explicit NSkin structural parent of independently meaningful editor objects
```

Surface, State, Tag, Family, Placement/Movement, and Editor Group are
orthogonal metadata/capabilities; they are not additional hierarchy levels.

Runtime frame identity, editor selection identity, appearance identity, and
movement ownership are separate concepts; none implies another. One stable ID
may legitimately serve more than one role, but shared code must not assume that
those roles always coincide.

The normal ownership direction is:

```text
CONTAINER
└─ COMPOSITE
   └─ ELEMENT
      ├─ SURFACE
      ├─ PART
      └─ CONTENT
```

Lower levels may be omitted when they add no useful identity. In particular,
a Composite may own Content directly when that visual has no independent
Element identity.

The central long-term rule is:

> Content defines swappable visual payload. Parts define reusable intrinsic
> control machinery. Elements define editable controls. Composition defines
> relationships. Window files map Blizzard UI into those structures.

Movement remains a separate editor capability. Structural ownership does not
automatically imply movement ownership.

Legacy canonical component kinds such as TEXT, ICON, and CHECKBOX remain
supported during migration. They are compatibility representations, not a
requirement that new work preserve the old taxonomy.

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

# 4. Content, Parts, Elements, Tags, and States

## 4.1 Content

Content is the smallest swappable visual payload. Supported Content representations include:

```text
TEXT
ICON
TEXTURE
ATLAS
GLYPH
```

Content does not receive an independent Skinning Mode selection merely because
it exists. Its identity belongs to the semantic slot owned by an Element or
Composite and must remain stable when presentation changes. A semantic Content
slot must therefore not derive its canonical ID from whether it currently
renders TEXT, ICON, GLYPH, TEXTURE, or ATLAS, nor from whether an icon-like
presentation is sourced from a texture file or an atlas.

For example:

```text
Find Group                 BUTTON Element
└─ Content                 stable slot
   └─ TEXT                 current presentation
```

may later become:

```text
Find Group                 BUTTON Element
└─ Content                 same stable slot
   └─ GLYPH                new presentation
```

without changing the Button identity or the Content slot identity.

Content representation describes presentation, not storage identity. Supported
representations may map to different runtime mechanisms, but changing the
rendering source of one semantic slot does not by itself create a new Content
identity.

## 4.2 Parts

A Part is reusable intrinsic machinery that is too structurally specific to be
normal Content but does not deserve an independent editor identity.

Initial canonical Parts are:

```text
TRACK
THUMB
```

They are shared by controls such as SCROLLBAR and SLIDER. Parts may own
appearance and local presentation geometry, but remain subordinate to their
owning Element. A Part does not receive independent editor identity merely
because it is editable; it may be edited through its owner's inspector. Promote
a Part to an Element only when it becomes independently meaningful as an editor
object.

Do not create a Part for a semantic visual that can be represented as Content.
For example, a checkbox checkmark and a collapse/expand arrow are Content,
because they may be rendered as GLYPH, ICON, TEXTURE, or ATLAS.

## 4.3 Elements

An Element is the smallest independently meaningful editor object. Clickability
does not define Element identity: a standalone heading or image may be an
Element when users need to select and customize it independently, while a
clickable internal control may remain subordinate to a larger owner.

Elements may own:

```text
ELEMENT
├─ Surface       optional
├─ Parts         optional
├─ Content       optional
└─ States        optional
```

Element types describe reusable technical structure, not the semantic name or
current appearance of one Blizzard control.

Examples include:

```text
BUTTON
SCROLLBAR
SLIDER
DROPDOWN
EDIT_BOX
WINDOW
```

A BUTTON is intentionally broad. Blizzard action buttons, checkboxes,
collapse/expand controls, close buttons, tabs, and similar controls may share
the same BUTTON Element implementation when their customizable structure is
the same.

Legacy TEXT, ICON, CHECKBOX, and similar canonical component APIs remain
available while existing windows migrate. New architecture should not create a
TEXT Element merely to wrap TEXT Content when the text has no independent
editor meaning.

## 4.4 Element Tags

Element type and semantic family are separate:

```text
Element type = reusable technical structure
Tag          = stable semantic/default appearance family
```

Examples:

```text
BUTTON + Checkbox
BUTTON + RoleCheckbox
BUTTON + ActionButton
BUTTON + CollapseButton
BUTTON + CloseButton
BUTTON + BottomTab
```

Semantic Element tags allow global styling of Blizzard families without
creating separate Element implementations. Normal appearance changes do not
change a semantic Element tag. A checkbox may be restyled to look like a large
action button while remaining tagged as Checkbox.

Semantic Element tags are metadata, not structural children, editor identities,
or movement owners. Composite presentation-family tags are a separate use of
tag metadata and may change during an explicit presentation-family conversion;
see Composite Style Tags.

## 4.5 States

State is an orthogonal runtime presentation context owned by the Element or
Composite. Blizzard remains authoritative for behavior and state transitions;
NSkin only maps the active state to presentation.

A State may override supported appearance properties of its owner, including
explicitly supported presentation geometry. State does not change structural
ownership, canonical identity, movement ownership, or Blizzard behavior.

Examples:

```text
BUTTON + Checkbox
├─ Unchecked
│  └─ Content: optional
└─ Checked
   └─ Content: GLYPH / ICON / TEXTURE / ATLAS

BUTTON + CollapseButton
├─ Expanded
│  └─ Content: GLYPH "-"
└─ Collapsed
   └─ Content: GLYPH "+"

Navigation Composite
├─ Unselected
└─ Selected
   └─ Surface override
```

Do not model action semantics such as ACTION, TOGGLE, or EXPAND_COLLAPSE as
appearance component types merely because Blizzard behavior differs. Window
adapters report the runtime state; NSkin does not redefine the action.

## 4.6 Surface

Surface remains a reusable presentation capability of an Element, Composite,
or Container. Generic background, border, and highlight properties belong to
Surface rather than to Content or Parts.

Surface does not create another editor identity, appearance owner, or movement
owner. Surface-only changes must continue to use the narrowest targeted refresh
path and must not force unrelated Content, Part, Composite, or window refresh.

During migration, existing canonical component renderers may continue to own
their current Surface implementation. New work should preserve reset/original
state ownership and targeted-refresh guarantees while moving toward the new
Element/Content/Part model.

---

# 5. Runtime, Editor, Appearance, and Movement Identity

Runtime frame identity, editor selection identity, appearance identity, and
movement ownership are separate concepts; none implies another.

Content and Parts may have stable appearance identities without becoming
independently selectable editor objects. Likewise, multiple presentation nodes
may belong to one Composite editor identity. A standalone Element may also
legitimately use one stable ID for both editor selection and appearance; the
invariant is that shared code must not require those identities to coincide.

For example:

```text
Dungeon Row Composite             one editor identity
├─ Surface
├─ Select                          BUTTON Element
│  └─ Tag: Checkbox
├─ Content                         dungeon-name slot
│  └─ TEXT
└─ Content                         level-range slot
   └─ TEXT
```

The Content slots retain stable identities even if their Content type changes.

These concepts must remain independently reasoned about even when an
implementation reuses one stable identifier for several of them.

Do not create a new Element type solely because a Content representation,
semantic tag, runtime frame, or appearance source differs.

---

# 6. STANDALONE

STANDALONE means one complete Element is exposed as one editor object.

Conceptually:

```text
STANDALONE
└─ BUTTON Element
   ├─ Surface
   └─ Content: TEXT
```

Typical behavior:

- one editor identity
- one stable Element identity
- its own highlight
- its own safe movement contract when movement is supported
- canonical options for its Element type, Tag, Content, Parts, and States

STANDALONE is a structural/editor relationship, not an Element type.

---

# 7. COMPOSITE

A Composite represents members under a lasting logical ownership relationship
that together form one logical editor object. Membership is structural and
semantic; it does not require every member to remain permanently attached to
Composite movement/layout.

Examples:

```text
checkbox option
├─ CHECKBOX
└─ TEXT

dungeon selector
├─ TEXT
└─ DROPDOWN

pagination
├─ BUTTON
├─ TEXT
└─ BUTTON

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
- one group Surface representing Composite presentation
- member-local X/Y
- reusable group layout metadata such as orientation/distribution when needed
- generic member attach/detach
- dock aggregation of member options

The Composite root is the structural/layout owner. The group Surface follows
Composite bounds and presentation state; it does not own the Composite or its
children. Member families remain independent presentation/layout participants,
and member-local placement composes with group placement rather than replacing
it. The Composite itself does not duplicate member appearance schemas.

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
→ remains a Composite member
→ no longer follows Composite-level movement
→ may receive an explicit safe independent placement/selection contract
```

Detachment changes movement/layout participation, not logical membership,
canonical identity, appearance identity, or reset ownership. It must not create
a duplicate canonical registration or a second appearance/reset owner merely to
support independent manipulation.

Detach must not blindly destroy Blizzard anchors. Independent selection or
movement is enabled only when an explicit safe contract exists.

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

## 7.5 Composite Style Tags

A Composite may declare a style tag when multiple Composite instances are
intended to share one global appearance family.

The tag is appearance-family metadata. It is not:

- an atomic component type
- a Composite type
- an editor identity
- a movement owner
- a replacement for stable Composite/member/target IDs

Composites with the same tag are eligible for shared tag-level appearance and
refresh behavior. Instance/member/exact-target customization remains separate
and must keep its existing stable identities.

Tags should distinguish global style families when two presentations need
independent global defaults even if they serve the same semantic role. For
example, tab collections may use presentation-specific families such as:

```text
Tabs.Text
Tabs.Icon
Tabs.Atlas
Tabs.Texture
```

Changing a Composite's presentation family may therefore change its
presentation-family tag without changing the Composite ID, member IDs, or
stable exact-target IDs. This is intentionally different from semantic Element
tags such as Checkbox or CloseButton, which remain stable across ordinary
appearance edits. Layout choices such as horizontal versus vertical orientation
remain normal Composite layout metadata unless they intentionally define a
separate global style family.



## 7.6 Selectable Composite Items

Selection is reusable Composite behavior, not an atomic visual component type.

A Composite that represents mutually selectable runtime items may declare a
`selection` contract. The contract resolves Blizzard's logical runtime selection
state (for example `Selected` / `Unselected`) and maps each participating
atomic member target back to its logical item. Atomic members opt in with
`selectionParticipant = true`.

Conceptually:

```text
Selectable Composite
├─ Item Surface (BUTTON)
├─ Item Icon (ICON, optional)
└─ Item Text (TEXT, optional)

runtime item A -> Selected
runtime item B -> Unselected
runtime item C -> Unselected
```

The selection contract supplies the state once for the logical item; Surface,
Icon, Text, and other participating atoms resolve that same state independently.
Window adapters remain responsible only for mapping Blizzard targets to the
logical item and reporting the runtime selection. They must not duplicate
Selected/Unselected state tables on every member.

State-scoped appearance is layered as:

```text
atomic family appearance
-> atomic family state appearance
-> exact runtime target state appearance
```

The exact runtime target keeps its stable base identity; state is an appearance
layer appended to that identity. This lets visually different controls share
the same selection behavior without creating specialized atomic types such as
`SIDE_TAB`, `ICON_TAB`, or `TEXT_TAB`.

Selection does not imply a particular visual composition. A text-only tab and
an icon/card navigation item may therefore use the same selectable behavior
while exposing different atomic members.

---

# 8. CONTAINER

A Container is an explicit NSkin structural parent whose children remain
independently registered and independently editable. Blizzard frame parenting
alone does not establish a Container relationship.

Example:

```text
CONTAINER
├─ TEXT
├─ ICON
├─ COMPOSITE
└─ BUTTON
```

A Container is appropriate when parent-level navigation, layout, or a meaningful
editable visual envelope makes the parent-child relationship useful. A
Container may own movement, but collective movement alone does not justify a
Container; use Editor Group for otherwise independent editor objects that only
need optional collective manipulation.

A standard Window Container is a canonical example: the WINDOW body and Header
Composite are independent editor children that structurally belong to the same
window.

Container children retain:

- their own canonical IDs
- their own editor identities
- their own atomic/Composite structure
- their own canonical options
- their own reset ownership

A Container may also own a Surface when the collection itself has a meaningful
editable visual envelope. That Surface is distinct from the Surfaces owned by
its children. Container-level layout controls such as spacing may be added to
the Container without turning child appearance into Container appearance.

Container placement belongs to the Container, not to its Surface. When a
Container exposes X/Y placement, those controls are zero-based group offsets:
Blizzard layout is `0 / 0`, and changing them translates the registered
runtime roots/children together. Native root chains must move as one group:
when one registered root is anchored to another registered root, the group
offset is applied only at the external/root anchor rather than accumulated
again on each dependent child. The Container Surface follows those moved roots.
Surface-local X/Y must not be used as a substitute for Container movement.

An ordered Container may also expose direction and spacing. Native Blizzard
anchors remain authoritative until the user creates a layout override. Once
overridden, the Container may reflow its current runtime roots horizontally or
vertically with the requested spacing; reset restores the captured Blizzard
arrangement.

Container Surface appearance has its own canonical appearance identity and
must use the shared Surface editor contract. A Surface-only edit refreshes that
Surface directly; it must not require re-skinning the Container children or
falling back to a full module/window refresh.

Declared children describe the stable structural family, not an assumption
that every child exists or is available at runtime. Conditional Blizzard
children such as tabs may be absent or hidden for a character; bounds,
presentation surfaces, and runtime iteration must use the currently available
children while preserving stable IDs for children that later become available.

Container Docked Window navigation mirrors the registered structure without
flattening child identity.

Equivalent semantic instances may explicitly declare a stable `familyID`
(and optional `familyLabel`) when they share a presentation contract and,
where intended, shared appearance defaults. Schema similarity alone does not
create a Family: two controls may use identical schemas while remaining
semantically distinct and independently editable.

Each family instance may retain a stable semantic identity for exact overrides.
A Container with one Composite family exposes that family's shared
member/appearance families directly beside the Container entry. A Container
with multiple Composite families exposes those families first; selecting one
drills into that family's members while retaining a route back to the
Container. A Composite without an explicit `familyID` is its own family.

Direct non-Composite children remain independent editor objects and are exposed
alongside Composite families. If a direct child has its own semantic parts, its
editor may replace the same primary Docked Window navigation row with those
parts rather than stacking another peer navigation row. State navigation is a
secondary layer beneath the selected part when needed.

Dock navigation is presentation metadata only. It must not merge canonical
IDs, appearance identities, reset ownership, or structural relationships.
User-facing Container names in inspector headings, breadcrumbs, and navigation
use "Name Group" rather than exposing the architectural term Container. This
display label does not change Container semantics or imply an Editor Group.

The inspector need not expose every architectural level as a separately
selectable navigation step. Content slots and Parts may be edited contextually
through their owner without gaining editor identity. Prefer the shallowest
inspector that preserves the user's current owner, state, and property context.

Structural ownership is also independent of movement ownership. A child that
moves indirectly because Blizzard anchors it inside a Container's runtime
movement root must still be registered as a Container child when it belongs to
that structure; incidental movement is not a substitute for declaring the
parent-child relationship.

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
Explicit member movement families also remain distinct when members share an
appearance parent. A row Surface and its subordinate button must never share
placement storage or movement propagation solely through appearance inheritance.

---

# 11. Surface Capability

Surface is the shared presentation contract for the visual area owned by an editor object.

It is not:

- a new atomic component type
- a composition mode
- a Container
- an Editor Group
- a replacement for the owner's semantic identity

Surface answers:

> What editable visual area surrounds or backs this owning element?

A Surface may provide shared behavior such as:

```text
Surface
├─ Geometry
├─ Background
├─ Border
└─ Highlight
```

Every Composite exposes a group Surface member. Window adapters may declare the Surface explicitly when Blizzard provides a meaningful visual target; otherwise shared composition infrastructure may provide the canonical Surface member from the Composite owner. Repeated families use the same Surface contract rather than inventing family-specific editor schemas.

Atomic components may additionally expose Surface capability on their own
appearance identity. An atomic Surface is not another Composite member and
does not acquire editor, movement, or composition ownership. It simply moves
overlapping generic presentation properties such as background, border, and
highlight out of the component-specific option schema.

The group Surface is the Composite's presentation layer and uses the same
canonical Docked Window options and sparse override system as other eligible
Surface owners. It is not the structural owner: selection, movement,
orientation/distribution, child membership, and composition relationships
belong to the Composite root. Member-local Surfaces belong to their atomic
members and do not merge into the group Surface.

A Surface may skin an existing Blizzard visual surface or use NSkin-owned non-interactive decoration. NSkin-created regions must not steal Blizzard clicks, tooltips, or hit regions.

Surface Background exposes a canonical `backgroundSource` selector: `REGULAR`
uses the owned Surface fill; `BLIZZARD` leaves the fill hidden and restores the
owner's explicitly audited native backdrop regions. The Enabled flag remains
independent. Native alpha is captured before first suppression and never
recaptured after edits or frame reuse. Regions retain Blizzard texture/atlas,
visibility, and interaction ownership. Functional selection/hover/disabled
overlays are not backdrop regions. Owners without a native backdrop have no
fill in Blizzard mode. Window backdrops retain their native textures for this
switch instead of being destructively cleared.
Audited native backdrop textures may opt into `fitToSurface`: their original
points and size are captured once, Blizzard mode anchors them to the owner's
Surface bounds, and leaving that mode restores only this owned geometry.
Atlas/texture content and functional overlays retain native ownership.
Audited backdrop artwork may additionally opt into `texCoordInset` to crop
baked decorative edges. Native texture coordinates are cached per atlas/texture
source before its first crop, reused without cumulative cropping, and restored
when leaving enabled Blizzard-background mode. Premade category card Icons use
this inset consistently to remove their baked rounded edge on every category.

Premade Groups category cards belong to a Category Cards Group Container with
its own Surface. Each category/filter pair has a stable Composite tagged `Card`,
with canonical Surface and TEXT members. Blizzard's CategoryButtons array is
rebound after its category-update lifecycle; recycled frame/list indices never
form saved identity. Card backdrop artwork (Icon) is declared separately
from native functional overlays. Category cards suppress the native highlight
and selected texture images and alpha while retaining Blizzard's selected-category/filter
state. Canonical Surface hover and selection feedback replace that artwork;
native-background mode preserves that backdrop when selected and uses the
canonical Surface border's accent color instead of an opaque selection fill.
That selection border is hidden on idle cards in native-background mode, so
the generic button's default border does not add a white edge to the artwork.
The native Cover bevel is suppressed with the feedback artwork; it is not
part of the native backdrop restored by the source selector.
The audited native feedback media/alpha are captured before suppression;
clearing their image content prevents native hover animation from revealing
them again without changing visibility or selection ownership.
Container and card appearance edits refresh
their own Surfaces, without reapplying the PVE window.
The Premade Groups title is a canonical TEXT child of that Container and joins
its movement roots; it retains independent typography, Surface and Position
options. Category card and Container backdrop textures fit their Surface bounds.

## 11.1 Surface Inheritance

Surface capability and Surface-default inheritance remain separate policies.

A Surface resolves through the appearance style appropriate to its owner. Different owners may therefore use the same Surface editor contract while retaining their canonical visual style and defaults.

Standalone-component Surface defaults must not leak into Composite, Container, or Window owners merely because they expose a Surface.

---

# 12. Appearance Inheritance

Canonical appearance resolves through a parent-to-child identity chain:

```text
NSkin defaults
→ global canonical component/style
→ window/scope override
→ shared element/member appearance identity
→ exact target appearance identity where the runtime family supports it
```

Lower-level overrides remain sparse. An exact target override changes only the selected properties and inherits all non-overridden values from its shared parent identity.

Composite members in separate Composite instances may intentionally share the
same appearance parent. That parent is an appearance family, not a structural
group: editing the family affects every member that inherits from it, while
exact-member overrides remain local. Stateful members extend the same chain per
state, so a shared family such as tab Text may have shared Selected/Unselected
appearance without collapsing the individual tab Composites.

When those sibling Composites are children of the same Container, editor focus
on a shared member family is also collective: selecting Text, Icon, or Surface
on one child selects/highlights the same inherited member family on the other
children that still inherit it. Shared member X/Y belongs to that same family,
so moving non-overridden Text/Icon content moves the family across sibling
Composites rather than only the clicked child. Exact overrides remain
individually focused. The dock member label describes the member family and
therefore does not change when the selected appearance state changes.

Composition does not create an implicit visual schema. Composite members retain their canonical appearance identities, while Surface uses the visual style owned by its Composite.

For repeated or pooled families, persistent customization must follow a stable semantic target identity rather than the recycled frame object or viewport position. The shared family appearance remains authoritative unless an explicit exact-target exception exists.

Editor grouping and appearance grouping remain separate concerns.

---

# 13. Shared Options and Configuration UI

Canonical option definitions belong with shared component/capability infrastructure, not in individual window adapters.

The Docked Window consumes those canonical definitions rather than reconstructing reduced copies.

Contextual property cells may present those same controls in accordions, with
labels above adaptive columns. Preserve declared property pairs when space
allows; long or unpaired controls may span the available width. Accordion
sections are presentation only: each logical property keeps its own scope,
inheritance source, setter, and reset boundary. Multiple sections may remain
open without changing canonical ownership or saved appearance identity.

Shared option metadata may place a Surface Enabled control beside its accordion
label instead of in the body. It remains the same canonical property; changing
it must not expand/collapse the section or change editor context.

Declared property pairs such as X/Y offsets and background color/opacity may
share a heading, inheritance label, and explicit combined reset action. Show a
common source only when both properties resolve to that source; otherwise omit
the common label and retain each property's source. Compact source labels show
Group for shared group/scope values, including edits at that shared scope, and
Override for exact-target exceptions (including their inherited base state);
global/default values have no visible source label. Detailed source descriptions
remain available to shared controls such as tooltips. A combined reset invokes the
existing logical resets for both properties at their supported scope/state,
without changing storage, identity, or unrelated overrides.

Dock navigation follows composition structure. Contextual drill-down reuses the
primary navigation row: selecting a Composite family or a structured direct
child replaces peer Container entries with that object's member/part entries,
while preserving a route to the Container. Secondary state selectors may appear
beneath that row, but equivalent peer navigation must not be duplicated in a
second row.

For a Composite, the Docked Window exposes one group context plus one entry
per canonical member/appearance family. Repeated runtime targets that share the
same member identity and appearance parent are represented once; same-kind
members with distinct appearance parents remain distinct because they are
different editable families. Switching the focused entry changes editor focus
only and must not create a second appearance identity or require reselection of
the underlying Blizzard control.

Conceptually:

```text
STANDALONE
→ canonical component-specific options
→ eligible Surface capability options

COMPOSITE
→ shared group Surface options
→ canonical member-specific options
→ eligible member Surface capability options
→ structural/position controls
→ sparse property overrides

CONTAINER
→ parent structural controls where relevant
→ hierarchical child/family navigation
→ independently addressable child options

EDITOR_GROUP
→ editor-group controls
→ member appearance remains independently canonical
```

All Surfaces use one shared editor contract. A window may identify which visual style its Surface represents, but must not define a private Surface option schema.

Overrides are property-level exceptions layered on canonical option groups. Adding an override must not clone a whole component configuration or fork its schema.

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

A shared family helper is appropriate when Blizzard exposes a known repeated
collection and NSkin explicitly declares those instances equivalent under one
semantic presentation contract. Sharing a template, schema, array, or provider
is supporting evidence, not by itself sufficient to create a Family.

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

A repeated family may expose one shared member identity across many runtime targets while also providing stable target-resolved appearance identities. This allows one family-wide configuration plus sparse exact-target exceptions without treating recycled frame identity as persistent state.

Exact-target position and appearance state must be keyed by that stable semantic identity. Recycling, scrolling, or reacquiring a physical frame must rebind the correct semantic customization rather than inheriting customization from the frame's previous content.

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

## 20.0 WINDOW Container/Header contract

A standard registered window is represented structurally as:

```text
Window Container
├─ WINDOW body
│  └─ Surface
└─ Header Composite
   ├─ Surface
   ├─ TEXT
   └─ BUTTON family (1..N controls)
```

The Window Container is structural only. It establishes ownership between the
independently editable Window body and Header Composite and does not duplicate
their appearance schemas.

The WINDOW body exposes its presentation through Surface. Window background,
border, and highlight remain Surface-owned. Window-specific relationship
controls that are not Surface properties remain inline on the WINDOW body.

The Header is one reusable Composite. Its Surface owns header presentation, its
TEXT member owns title typography/color, and its BUTTON member is a family that
may contain the close button plus any number of additional header controls.
Header buttons remain canonical BUTTON targets; multiple controls do not create
a nested buttons Composite.

Existing window.header appearance remains the inheritance/default source during
the migration. Header members receive stable child appearance identities while
preserving the existing header-controls family appearance identity. Adapters may
provide exceptional controls/anchors, but must not recreate the standard Window
Container/Header Composite structure.

This structure is inherited by windows using standard window chrome.

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

ICON has reusable presentation variants. Presentation variant describes texture
source/ownership, not component identity:

```text
ICON
├─ Default Icon
│  └─ skins an existing Blizzard/native icon Texture
└─ Texture Icon
   └─ owns/reuses an NSkin Texture sourced from registered/media texture data
```

Both variants use the same canonical ICON appearance contract, Surface,
Shape/Size/Crop/Zoom behavior, targeted refresh rules, reset ownership, and
interaction presentation. A window adapter declares the required variant and
media/state providers, but must not reimplement Texture Icon creation, clipping,
border ownership, media assignment, or presentation transaction behavior.

General invariants:

- crop changes sampled texture coordinates without stretching the rendered icon
- zoom changes texcoords only
- presentation changes must not unexpectedly resize/move the parent interaction target
- shapes and borders remain shared ICON behavior
- Blizzard interaction/state ownership is preserved
- pooled ICON targets must release/reacquire runtime state safely
- lifecycle hooks attached to ICON textures/owners must treat mutations made by
  the active NSkin presentation transaction as internal and must not recursively
  re-enter the same presentation refresh; hooks remain responsible for genuine
  external Blizzard mutations after the transaction completes
- when an exceptional adapter owns ICON clipping/border geometry, any geometry
  preparation required by a targeted ICON refresh must run inside the canonical
  ICON presentation transaction so owner hooks cannot create a second render

A special semantic role or a Texture Icon media source does not justify a new
icon component type if the visual contract is still ICON.

## 20.3 Buttons

BUTTON is the single canonical atomic button component.

Text, glyph, atlas, icon, primary-action, close, navigation, and other button
presentations do not create separate component identities. They are native/default
presentation descriptors of BUTTON and may be overridden by the user.

A Blizzard button keeps its native width, height, and content presentation by
default. Customization may change those properties independently; for example, a
native square close-glyph button may become a rectangular text button without
changing component identity.

Legacy names such as ACTION_BUTTON, GLYPH_BUTTON, and ICON_BUTTON are migration
inputs only and must normalize to BUTTON rather than registering separate shared
component types.

## 20.3.1 Component presentation states

An atomic component may declare multiple reusable presentation states without
creating new component identities. State is part of appearance context.

For BUTTON this supports controls such as collapse/expand, play/pause, or other
visual state pairs while keeping one canonical BUTTON component.

A state descriptor may provide:

```text
id
label
appearanceID
defaultContent
getStateID(target)
previewState(target, stateID)
previewRuntimeState = true | false
```

Skinning Mode selects the runtime state of the exact clicked target. The Docked
Window may switch the edited state explicitly. By default, switching state also
previews that state on the selected runtime target when the adapter provides a
safe preview callback. Controls where changing state has gameplay or other
meaningful side effects opt out with `previewRuntimeState = false`.

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

A tab collection should normally be a REGULAR Composite built from canonical
members and native Blizzard interaction targets. Orientation, spacing, and
distribution belong to Composite layout metadata; selected/unselected visuals
use normal component presentation states rather than a TAB-specific atomic
identity.

For the text-tab presentation, the target editor structure is:

```text
REGULAR COMPOSITE
Tag = Tabs.Text
├─ Surface
│  └─ shared tab-button surfaces
└─ TEXT family
   └─ tab labels
```

When selected and unselected tabs have different visual treatment, the Surface
and any affected content member may each expose the same semantic state pair
through the normal component-state system. The Blizzard buttons remain the
functional interaction targets; composition only defines how their presentation
is edited.

Alternative tab presentations reuse the same Composite identity and stable
target identities while changing presentation/style family, for example
`Tabs.Icon`, `Tabs.Atlas`, or `Tabs.Texture`. Presentation conversion must
not replace the Composite or assign new canonical IDs merely because the visible
content changes.

A breadcrumb bar should normally be a Composite of canonical buttons. Introduce a specialized atomic button contract only if the breadcrumb button itself has genuinely reusable visual/state behavior that normal BUTTON cannot express.

Navigation is semantic/layout context, not by itself a canonical visual component family.

This is why `Components/NSkin_ComponentsNavigation.lua` and its dock option counterpart are transitional files. Their useful atomic behavior should migrate to the appropriate canonical owners during later refactor parts.

---

# 23. Popup and Shell-Only Window Architecture

Reusable popup families belong in shared popup adapter infrastructure when their Blizzard structure is genuinely shared.

`Windows/NSkin_ShellOnly.lua` groups Blizzard window adapters whose NSkin support is intentionally limited primarily to shared window chrome because internal content is forbidden, inaccessible, unsuitable for mutation, or deliberately left Blizzard-owned.

Shell-only is an adapter organization, not an atomic component, composition mode, capability, or editor type. A shell-only window may still register explicitly safe canonical child controls. Having one or a few supported child controls does not require a separate window adapter when the window remains primarily shell-only.

If a shell-only window later becomes comprehensively skinnable, it may graduate to its own normal `Windows/NSkin_<Window>.lua` adapter.


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
- runtime-target focus for repeated families
- editor interaction policy

It must distinguish:

```text
atomic appearance identity
shared member identity
exact runtime appearance identity
editor identity
composition relationship
movement ownership
selection policy
window/container membership
input ownership / occlusion
```

Do not couple these concepts unnecessarily.

Highlight presentation and input ownership are separate surfaces.

For repeated members, Skinning Mode may focus one exact runtime target while the member remains part of a shared family. Exact overrides belong only to that target's stable appearance identity; ordinary shared selection/customization continues to address the family.

An editor element is interactive only when its underlying Blizzard element is the topmost valid UI target at the pointer. Modal UI and unrelated windows must win over Skinning Mode.

Use event/lifecycle-driven invalidation rather than `OnUpdate` polling for occlusion.

Selection policy must remain replaceable without changing canonical IDs, composition membership, appearance ownership, movement ownership, or reset ownership.

---

# 27. Docked Window

The Docked Window is the compact inspector for the selected editor object.

Its owned presentation uses square corners, an opaque dark shell and inset
property panel, owner/member breadcrumbs, an Editing dropdown, a segmented
state selector, and a single Design page. No Tokens/Code pages or inheritance
tags are exposed yet. Inheritance resolution, source tooltips, storage, and
reset boundaries remain canonical. Shared property views accept an optional
inspector palette; color controls show a small swatch and hex value instead of
coloring the entire control. This palette is confined to owned inspector
controls and never alters the appearance of the edited Blizzard window or
other configuration pages. Media icons may stand in for missing section icons.
The inspector has a stable 432-unit width and a 704-unit preferred height,
clamped to available screen space; overflow uses the owned vertical scrollbar.
Declared property pairs use two columns when there is sufficient width, with
individual headings and reset buttons. Accordion expansion and editing focus
survive local commits. The shell's dock/float action shares the existing docking
and manual placement state.

A contextual inspector keeps owner, focused member, editing scope, and state
visible while properties expand in place. A decorative window-title row is
optional. Auxiliary debug/grid tools must not change property width or editor
navigation. Local edits preserve focus, scope, state, expansion, scroll, and
keyboard input; explicit context navigation may change the focused controls.
The `All` state label denotes the inherited base appearance, not mutation of
Blizzard's actual state. Validate a focused pooled target's semantic identity
before applying a preview or exact-target edit; never follow a recycled frame
into another semantic instance.

It renders canonical option groups rather than duplicate schemas.
The contextual accordion renderer supports Composite members, Container owners,
and standalone controls through the same canonical option contracts. Owner
editing must not invent a synthetic Composite member or appearance identity;
Container/part navigation remains in the primary navigation row.
Adapters may opt an entire registered element into this presentation with
`contextualInspector`. Composite members inherit that policy unless explicitly
excluded; standard window Header/Container registrations carry the body's policy.
Anchor Groups use it when all registered members opt in. PVEFrame registrations
use this layout across their window chrome, navigation, finder controls, rewards,
PvP controls, and bottom tabs. Scrollbar parts expand on one page. Canonical
button content actions remain available in their accordion and do not become
override properties or acquire reset ownership.
Dungeon Finder's reused Random scroll content is a `Random Dungeon Group`
Container around the existing header and reward Composites. Random queues and
world-event dungeons using that content retain the same text/reward appearance
IDs; the selected dungeon does not create a new appearance family. The specific
Dungeon Rows Container is selectable only while its own view is visible.
Random Header and Rewards declare separate canonical Surface members anchored
to their own visible content, rather than sharing the entire scroll child as
their presentation target. Position groups precede appearance groups in the
contextual accordion renderer.
Random content's typed registrations retain the original rendering/baseline
and appearance identities but do not expose duplicate selection overlays.
Their Composite members use those same identities for edits and resets, with
independent member movement families and targeted typed refresh callbacks.
Member Position is injected unless an explicit nested navigation definition
owns that placement context. A top-level preset Position entry must not be
mistaken for nested navigation. Random content uses shared independent anchor
offset application: native multi-point anchors are retained, sibling-relative
offsets are compensated, and reset restores the captured native points. Header
and Rewards Surface Position translates only that Composite's declared content;
the outer Container Position continues to translate the entire viewport.
While Random content has member or Composite offsets, its audited native
content ancestors allow overflow rendering. Their original clipping flags are
captured before mutation and restored when those offsets are cleared. This
also captures the scroll child's original parent and frame level. While offsets
are active, the reused child renders under the Random owner to escape native
ScrollFrame viewport clipping. An empty, noninteractive scroll child retains
the native scroll range; targeted size/vertical-scroll hooks keep it in sync
with the original named content. Clearing offsets restores the original scroll
child assignment, parent and level. Native anchor references and reward controls remain intact; icon
masks are unchanged. Protected/forbidden targets and combat are skipped.
Random Header and Rewards declare a `dragMemberID` pointing to their own Surface
member. Root dragging uses the canonical member movement path, matching Surface
X/Y rather than moving their shared scroll child. The title member uses tight
text selection bounds without changing its native layout width.

Canonical appearance opacity defaults are 1 (100%), including slider glow;
highlight (`hoverAlpha`) defaults remain 0.10. Existing enabled/disabled Surface defaults and saved
appearance overrides are preserved. Opacity controls support the full 0–1 range.

Target presentation:

```text
STANDALONE
→ canonical atomic/capability options

COMPOSITE
→ shared Surface options
→ canonical member options
→ structural/position controls
→ sparse override list
→ attach/detach where supported
→ member/family X/Y
→ exact-target X/Y where the member exposes stable runtime identities

CONTAINER
→ parent structural controls
→ independently addressable children

EDITOR_GROUP
→ collective editor controls
→ independent member appearance remains canonical
```

Overrides are sparse property-level exceptions over canonical member/Surface
appearance. Shared family settings remain authoritative for non-overridden
properties; an exact-target override is keyed by the target's stable semantic
appearance identity, never by recycled frame identity.

Position overrides are axis-local: an exact X or Y override replaces the shared
family value on that axis, while the non-overridden axis continues to inherit
the family value. Editing or clearing one target's overrides must not mutate
sibling targets. Presentation categories in the inspector are UI organization
only and do not change ownership.

A window adapter may declare identity, target resolution, and presentation metadata, but it must not reconstruct generic dock or override controls.

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

Do not add speculative optimization passes without a measured user-visible problem.

Preserve targeted invalidation and local refresh ownership.

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

For pooled/recycled lifecycle bursts, repeated work may be coalesced within the
owning family when measurement shows redundant rescans. Such a transaction
should snapshot the relevant runtime targets once, reuse that snapshot for the
local dependency graph, and treat already-applied state as a no-op. This must
remain local lifecycle handling, not become global polling or generic debounce
infrastructure.

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

# 31. Legacy Compatibility and Incremental Migration

The architecture in this document defines the project-wide destination. It does not require all existing windows or legacy abstractions to be migrated in one dedicated refactor phase.

Existing transitional files, component types, grouping helpers, and compatibility paths may remain while they still serve working windows safely.

Use these rules:

- new work should use the target architecture where practical;
- do not introduce new dependencies on an abstraction that has already been superseded;
- migrate legacy structures when they are directly involved in current window work, block canonical behavior, or create a real shared inconsistency;
- when a legacy abstraction is migrated, prefer a reusable shared replacement rather than a window-specific substitute;
- preserve stable IDs, reset ownership, Blizzard baselines, interaction ownership, and default behavior during migration;
- do not require unrelated windows to be migrated or exhaustively revalidated solely to satisfy a refactor milestone;
- do not perform broad cleanup only for architectural purity when the existing path is stable and does not obstruct current development.

Legacy compatibility is therefore allowed, but architectural debt should not grow.

---

# 32. Development and Migration Strategy

NSkin development is window-driven and incremental.

The normal priority is to make Blizzard windows correctly skinned, customizable, and consistent with the shared architecture. Architectural migration should support that work rather than block it.

When working on a window:

```text
existing implementation
        ↓
keep stable legacy paths that are unrelated to the task
        ↓
use current canonical architecture for new work
        ↓
migrate touched legacy structures when necessary or clearly beneficial
        ↓
validate the affected behavior
        ↓
continue normal window development
```

Shared architectural changes should be validated where they are actually exercised, then reused as additional windows encounter the same pattern.

A project-wide migration pass is appropriate only when a shared legacy system itself becomes a practical blocker, causes repeated defects, or must be removed to support the target architecture safely.

The target architecture remains authoritative even when adoption is incremental.

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
- Surface decoration gaining semantic child/container responsibilities
- Composite surfaces bypassing the shared Surface editor contract
- standalone Surface defaults leaking into Composite/Container owners
- exact-target overrides keyed to recycled frame identity rather than stable semantic identity
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

`ARCHITECTURE.md` describes stable project-wide rules and the target architecture. It intentionally does not track per-window migration status or prescribe a mandatory refactor sequence.

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
├─ Shared Appearance Capabilities
│  └─ Surface
│     ├─ geometry/background/border/highlight
│     └─ canonical Docked Window + override contract
│
├─ Composition
│  ├─ STANDALONE
│  ├─ COMPOSITE
│  │  ├─ type: REGULAR by default
│  │  └─ canonical Surface member
│  ├─ CONTAINER
│  └─ EDITOR_GROUP
│
├─ Skinning Mode
│  ├─ selection
│  ├─ hover/highlights
│  ├─ input ownership
│  ├─ exact runtime-target focus
│  ├─ Shift-drag movement
│  └─ modal/occlusion policy
│
├─ Docked Window
│  ├─ canonical option presentation
│  ├─ shared Surface/member editing
│  ├─ sparse shared/exact overrides
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
