# Transcript Lane Flattening Upgrade Plan

## Purpose

This document defines how to redesign the live lane transcript into a flatter,
less layered surface.

This is intentionally scoped to the transcript lane only.

It does not cover:

- settings
- configuration sheets
- dormant connection pages
- workspace navigation outside the transcript lane

The immediate goal is to remove the current "card inside card inside card"
composition pattern from the transcript without losing transcript meaning,
runtime parity, or actionability.

## Why This Document Exists

The current transcript architecture has drifted into a repeated visual pattern:

- a transcript item gets an outer framed surface
- the item then renders one or more inner panels
- the inner panels then contain chips, badges, icon containers, or more boxed
  rows

That creates an over-surfaced lane where structural chrome is louder than the
actual turn content.

This document answers:

1. what is structurally wrong in the current transcript
2. what the flattened transcript model should be
3. which current widgets should be kept, rewritten, or deleted
4. what the safest upgrade sequence is

## Source Anchors

Primary lane and transcript files:

- [transcript_list.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/transcript_list.dart)
- [conversation_entry_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/conversation_entry_card.dart)
- [chat_screen_shell.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/chat_screen_shell.dart)
- [flutter_chat_screen_renderer.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/flutter_chat_screen_renderer.dart)
- [chat_screen_contract.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/chat_screen_contract.dart)
- [chat_transcript_surface_projector.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/chat_transcript_surface_projector.dart)

Current shared surface primitives affecting transcript layering:

- [pocket_transcript_frame.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/ui/surfaces/pocket_transcript_frame.dart)
- [pocket_panel_surface.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/ui/surfaces/pocket_panel_surface.dart)
- [pocket_meta_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/ui/primitives/pocket_meta_card.dart)

Prior analysis that should remain upstream context:

- [037_designer-redesign-brief.md](/Users/vince/Projects/Pocket-Relay/docs/037_designer-redesign-brief.md)
- [041_transcript-information-hierarchy-spec.md](/Users/vince/Projects/Pocket-Relay/docs/041_transcript-information-hierarchy-spec.md)
- [042_codex-tui-flutter-widget-parity-gaps.md](/Users/vince/Projects/Pocket-Relay/docs/042_codex-tui-flutter-widget-parity-gaps.md)
- [044_current-visual-style-audit.md](/Users/vince/Projects/Pocket-Relay/docs/044_current-visual-style-audit.md)

## Current Structural Problem

The transcript currently has too many widgets that believe they own a full
surface shell.

The result is not just "too many cards" visually. It is an ownership problem.

The surface boundary for a transcript item is currently ambiguous:

- sometimes the lane owns the structure
- sometimes the transcript item owns it
- sometimes a shared transcript frame owns it
- sometimes a sub-block inside a transcript item owns another panel

That ambiguity creates repeated framing and repeated emphasis.

### Current layering stack

At the lane level:

- [`TranscriptList`](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/transcript_list.dart)
  lays out a vertical stream of transcript entries
- each entry is routed through
  [`ConversationEntryCard`](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/conversation_entry_card.dart)

At the shared transcript primitive level:

- many entries use
  [`PocketTranscriptFrame`](/Users/vince/Projects/Pocket-Relay/lib/src/core/ui/surfaces/pocket_transcript_frame.dart)
  as a default wrapper
- status and error entries use
  [`PocketMetaCard`](/Users/vince/Projects/Pocket-Relay/lib/src/core/ui/primitives/pocket_meta_card.dart),
  which itself uses
  [`PocketPanelSurface`](/Users/vince/Projects/Pocket-Relay/lib/src/core/ui/surfaces/pocket_panel_surface.dart)

At the item level:

- SSH surfaces use an outer frame and inner detail panels
- work log uses an outer frame and many row-level mini-cards
- changed files uses an outer frame and row-level decorated pills/chips
- plan updates use an outer frame and boxed step rows
- approval and user-input states use framed boxes even when the surface is
  mostly a form or action row

This is the core issue:

the transcript is implemented as a stack of local component treatments rather
than as one coherent lane document.

## Findings From The Current Code

### 1. The transcript already has a flat baseline, but only for some items

[`AssistantMessageCard`](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/assistant_message_card.dart)
is already mostly correct structurally:

- no framed shell
- no nested panel
- content is primary
- streaming state is shown with a single progress indicator

[`UsageCard`](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/usage_card.dart)
and
[`TurnBoundaryCard`](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/turn_boundary_card.dart)
also lean closer to a flat transcript document model.

This matters because the redesign does not need a brand new lane architecture.

It needs the rest of the transcript to stop fighting that flat model.

### 2. `PocketTranscriptFrame` became a default answer instead of an exception

`PocketTranscriptFrame` is currently used for many different transcript item
families:

- reasoning
- plan update
- proposed plan
- changed files
- approval request
- approval decision
- user input request
- user input result
- work log group
- SSH surfaces

That is too broad.

Some of those items are true blockers and may deserve a surfaced container.
Many do not.

The frame primitive is not the root problem by itself.

The problem is that it is currently the default transcript pattern rather than
the exception reserved for blocking or high-consequence states.

### 3. Status signaling is stacked redundantly

Several item families currently use multiple concurrent signals for one idea:

- accent border
- tinted background
- colored title
- icon
- badge or chip
- row-level containers underneath

That violates the hierarchy rules already described in
[041_transcript-information-hierarchy-spec.md](/Users/vince/Projects/Pocket-Relay/docs/041_transcript-information-hierarchy-spec.md).

The transcript is often saying the same thing five times visually.

### 4. Runtime detail is boxed too aggressively

The deepest offenders are:

- [`work_log_group_card.dart`](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/work_log_group_card.dart)
- [`ssh_card_frame.dart`](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_card_frame.dart)
- [`changed_files_card.dart`](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/changed_files_card.dart)

These files all take operational detail and then assign multiple nested
containers to it.

That is upside down.

Operational detail should usually be:

- dense
- secondary
- inline
- progressively disclosed when long

It should not become a nested card system inside the transcript.

### 5. The current widget names encode the wrong mental model

The transcript still uses `Card` in many names:

- `ConversationEntryCard`
- `ReasoningCard`
- `PlanUpdateCard`
- `ChangedFilesCard`
- `WorkLogGroupCard`
- `StatusCard`
- `ErrorCard`

That is not just naming.

It reflects a design assumption that each transcript event should be a self-
contained card surface.

The flatter redesign should move toward item names that describe transcript
meaning rather than decorative form.

## Transcript Redesign Target

The lane should behave like a structured conversation document, not a stack of
component demos.

### Core structural rule

There should be only one strong surface boundary by default:

- the lane itself

Transcript items should normally be content blocks inside that lane.

Only a small number of transcript states should introduce their own visible
container.

### Allowed visual layers

The flattened lane should use only these layers:

1. Lane surface
- background, overall padding, scroll rhythm

2. Transcript item rhythm
- spacing, alignment, width, type scale

3. Inline emphasis
- eyebrow label
- left rule
- subtle tint strip
- compact code inset
- divider

4. Blocker surface
- reserved only for action-required or failure states

Everything else should be removed.

### Allowed transcript item classes

Every transcript item should fall into one of these classes:

#### 1. Message

Examples:

- user message
- assistant message

Characteristics:

- content-first
- little or no framing
- alignment carries meaning

#### 2. Annotation

Examples:

- reasoning
- plan update
- proposed plan
- usage
- turn boundary
- status
- error
- work log
- changed files when only informational

Characteristics:

- secondary to the main answer
- typically flat
- may use inline label, divider, or inset
- should not feel like its own standalone screen inside the lane

#### 3. Blocker

Examples:

- approval request
- pending user input request
- SSH trust/failure states
- possibly changed files when review/action is mandatory

Characteristics:

- one visible container is allowed
- actionability is primary
- detail stays subordinate to the required action

## Proposed Ownership Model

The redesign should create a clearer ownership split.

### Lane owns

- transcript width rhythm
- inter-item spacing
- overall background
- pinned item region framing strategy

### Item owns

- message or annotation semantics
- local content layout
- whether progressive disclosure is needed

### Shared primitive layer owns

- lightweight transcript annotations
- blocker surface treatment
- code inset treatment
- eyebrow/label rows

### Shared primitive layer should not own

- a universal transcript card shell
- a universal rounded bordered frame for all item types

## Proposed New Primitive Set

This should replace the current "frame-first" approach.

### `TranscriptAnnotation`

Purpose:

- flat, secondary transcript item wrapper

Capabilities:

- optional eyebrow label
- optional accent left rule
- optional inline trailing status
- constrained width
- no default border
- no default shadow

Used for:

- reasoning
- plan update
- proposed plan
- status
- error
- changed files summary
- work log group

### `TranscriptBlocker`

Purpose:

- surfaced transcript item for action-required or blocking states

Capabilities:

- one container
- one emphasis strategy
- action row
- optional sections below

Used for:

- approval request
- pending user input request
- SSH failures and trust blockers

### `TranscriptCodeInset`

Purpose:

- dense, secondary detail block inside annotations or blockers

Capabilities:

- compact monospace styling
- subtle background only
- no border by default
- optional copyable/selectable text

Used for:

- SSH fingerprint/details
- command/query snippets
- path and diff summaries

### `TranscriptDividerLabel`

Purpose:

- turn separators and low-chrome metadata rows

Used for:

- turn boundary
- timing separators
- settled markers

### `TranscriptActionRow`

Purpose:

- standard action layout inside blockers

Used for:

- approve/deny
- submit user input
- retry/open settings

## Widget-By-Widget Upgrade Direction

This section is the actual keep/change/delete audit for the transcript lane.

### Keep mostly as-is

#### `AssistantMessageCard`

File:

- [assistant_message_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/assistant_message_card.dart)

Why:

- already content-first
- already flat
- already close to a document model

Needed changes:

- minor typography and spacing tuning only
- possibly rename later to remove `Card`

#### `UserMessageCard`

File:

- [user_message_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/user_message_card.dart)

Why:

- a user bubble is one of the few places where a contained shape still makes
  semantic sense

Needed changes:

- simplify border/tint if necessary
- ensure it remains the only routinely rounded bubble treatment

#### `UsageCard`

File:

- [usage_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/usage_card.dart)

Why:

- already flat
- already subordinate
- behaves like metadata rather than a panel

Needed changes:

- probably rename later
- keep visually quiet

#### `TurnBoundaryCard`

File:

- [turn_boundary_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/turn_boundary_card.dart)

Why:

- already uses divider logic rather than panel logic

Needed changes:

- maybe reuse a new divider primitive

### Rewrite as flat annotations

#### `ReasoningCard`

File:

- [reasoning_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/reasoning_card.dart)

Current issue:

- uses `PocketTranscriptFrame` even though reasoning is supporting context
- visually risks outranking the actual assistant answer

Target:

- compact annotation block
- small label row
- optional running state
- markdown body below
- no bordered frame

#### `PlanUpdateCard`

File:

- [plan_update_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/plan_update_card.dart)

Current issue:

- outer frame plus boxed step rows

Target:

- flat checklist section
- steps shown as rows in one list
- status can be communicated by icon or a single inline status token, not a
  boxed row plus badge

#### `ProposedPlanCard`

File:

- [proposed_plan_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/proposed_plan_card.dart)

Current issue:

- treated like a prominent card when it is usually a secondary planning
  artifact

Target:

- annotation treatment with collapse/expand preserved
- header stays, but without framed container

#### `StatusCard`

File:

- [status_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/status_card.dart)

Current issue:

- inherits panel treatment through `PocketMetaCard`

Target:

- inline status note
- icon plus eyebrow plus body
- no border panel unless the status is truly blocking

#### `ErrorCard`

File:

- [error_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/error_card.dart)

Current issue:

- all errors currently look like compact meta cards, regardless of severity

Target:

- non-blocking errors become flat annotations
- only blocking/fatal error states should use blocker treatment

#### `ChangedFilesCard`

File:

- [changed_files_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/changed_files_card.dart)

Current issue:

- outer frame
- row containers
- status chip
- action chip
- row icon

This is a classic over-surfaced stack.

Target:

- one flat changed-files section
- header summary first
- rows rendered as dense file lines
- operation shown by icon or prefix token, not multiple chips
- review action presented as a row affordance, not a fake chip

#### `WorkLogGroupCard`

File:

- [work_log_group_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/work_log_group_card.dart)

Current issue:

- outer frame
- repeated mini-card rows
- inner icon boxes
- repeated tinted containers

This is currently the heaviest transcript item family.

Target:

- one flat activity section
- header with count and expand/collapse
- entries as dense rows
- running/failure state shown with one signal only
- command/query/detail snippets rendered as inline code inset only when needed

This rewrite must stay aligned with the parity concerns documented in
[042_codex-tui-flutter-widget-parity-gaps.md](/Users/vince/Projects/Pocket-Relay/docs/042_codex-tui-flutter-widget-parity-gaps.md).

The redesign should not hide the need for future runtime-surface splitting.

### Rewrite as blockers

#### `ApprovalRequestCard`

File:

- [approval_request_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/approval_request_card.dart)

Target:

- blocker surface
- title and consequence first
- actions obvious
- supporting text below

The card does not need nested sections unless the request has real extra detail.

#### `ApprovalDecisionCard`

File:

- [approval_decision_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/approval_decision_card.dart)

Target:

- flatter resolved-state annotation or quiet settled blocker
- much less prominent than the pending request

#### `UserInputRequestCard`

File:

- [user_input_request_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/user_input_request_card.dart)

Target:

- blocker surface
- prompt first
- form fields below
- no extra framed sections inside

The field stack itself is legitimate product UI and should not be mistaken for
decorative nesting.

The important rule is that the request surface remains the only container.

#### `UserInputResultCard`

File:

- [user_input_result_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/user_input_result_card.dart)

Target:

- quiet resolved annotation
- no heavy blocker styling once the action is complete

#### SSH family

Files:

- [ssh_card_frame.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_card_frame.dart)
- [ssh_card_host.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_card_host.dart)
- [ssh_unpinned_host_key_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_unpinned_host_key_card.dart)
- [ssh_connect_failed_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_connect_failed_card.dart)
- [ssh_host_key_mismatch_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_host_key_mismatch_card.dart)
- [ssh_auth_failed_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_auth_failed_card.dart)
- [ssh_remote_launch_failed_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_remote_launch_failed_card.dart)

Current issue:

- one outer frame
- one metadata panel
- one or more detail panels

Target:

- one blocker container total
- host/context metadata inline under title
- detail sections become `TranscriptCodeInset`
- actions remain at bottom

The SSH family is a blocker domain and may keep one surface, but no inner
surfaces.

### Delete or retire as transcript defaults

#### `PocketTranscriptFrame`

File:

- [pocket_transcript_frame.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/ui/surfaces/pocket_transcript_frame.dart)

Decision:

- do not delete immediately
- retire it as the default transcript wrapper

Future role:

- either blocker-only primitive
- or fully replaced by a new blocker primitive

#### `PocketMetaCard`

File:

- [pocket_meta_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/ui/primitives/pocket_meta_card.dart)

Decision:

- not appropriate as a transcript default

Future role:

- either removed from transcript usage
- or rewritten into a flat metadata row primitive

## Lane-Level Changes Needed

Flattening the transcript is not only a widget rewrite.

Some lane-level behaviors should also change.

### 1. `TranscriptList` should own transcript rhythm more explicitly

File:

- [transcript_list.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/transcript_list.dart)

Current state:

- every item gets the same separator spacing

Problem:

- a flat transcript needs smarter rhythm than "8 px between all cards"

Target:

- spacing varies by transcript class
- message-to-message spacing can stay compact
- blocker spacing can be larger
- turn boundaries should breathe differently from content annotations

This likely means the projector or item contract layer should provide a
presentation class or spacing intent.

### 2. Pinned request region should visually match blocker semantics

File:

- [transcript_list.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/transcript_list.dart)

Current state:

- pinned items are the same widgets rendered in a lower constrained region

Problem:

- if blockers are the only surfaced items, the pinned region must not look like
  a second floating card stack

Target:

- pinned blockers remain visually coherent with main-lane blockers
- avoid additional panel chrome around the pinned region itself

### 3. Item contracts may need presentation classification

Files:

- [chat_screen_contract.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/chat_screen_contract.dart)
- [chat_transcript_surface_projector.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/chat_transcript_surface_projector.dart)

Current state:

- transcript items are projected semantically, but not grouped into
  presentation classes

Target:

- add an app-owned presentation classification such as:
  - message
  - annotation
  - blocker
  - divider

That gives the lane enough information to own spacing and density without
hardcoding everything inside each widget.

## Best Upgrade Path

This is the recommended order of work.

It is designed to reduce churn and avoid a half-flat, half-card transcript.

### Phase 0: Add flat transcript primitives before migrating items

Create the new shared primitives first:

- `TranscriptAnnotation`
- `TranscriptBlocker`
- `TranscriptCodeInset`
- `TranscriptDividerLabel`
- `TranscriptActionRow`

Why first:

- this prevents every rewritten item from inventing its own new mini-system
- it replaces one bad shared default with a better shared default

### Phase 1: Convert the easiest annotation families

Rewrite:

- reasoning
- status
- error
- proposed plan
- plan update

Why first:

- these are structurally straightforward
- they immediately reduce frame count
- they help validate the flat annotation language

### Phase 2: Rebuild the dense operational families

Rewrite:

- changed files
- work log group

Why second:

- these are the biggest card-stack offenders
- they need the annotation and code-inset language established first

Important note:

Do not let the visual flattening hide unresolved parity work.

If a family still needs to be split semantically later for Codex parity, keep
the presentation seams ready for that split.

### Phase 3: Rebuild blocker families

Rewrite:

- approval request
- approval decision
- user input request
- user input result
- SSH states

Why third:

- blockers need the strongest and most disciplined surface treatment
- by this point the flat lane language will already be established, so the
  blocker language can be intentionally exceptional

### Phase 4: Move spacing ownership into the lane

Update:

- `TranscriptList`
- possibly transcript item contracts/projectors

Why fourth:

- after item families are recategorized, lane-level spacing can be tuned
  coherently

This is where the transcript stops behaving like a list of unrelated widgets
and becomes one document again.

### Phase 5: Rename remaining "Card" terminology

Only after the structural migration is stable:

- rename card-oriented transcript widgets to transcript item names that match
  semantics, not decorative form

Why last:

- avoid rename churn while the structure is still moving

## What Not To Do

These are specific failure modes to avoid.

### 1. Do not flatten by making everything a plain `Padding + Column`

That would remove card chrome but also remove the chance to create a coherent
shared transcript language.

The redesign still needs real shared primitives.

### 2. Do not preserve old card semantics under new names

Renaming `PocketTranscriptFrame` to something softer while still using it for
every item would be churn without correction.

### 3. Do not mix blocker and annotation language

If blockers and annotations use the same container strength, the user loses the
ability to scan for required action.

### 4. Do not let Widgetbook drive transcript ownership

The transcript redesign must be app-owned.

Preview stories can follow later.

### 5. Do not solve density problems with more chips

The current transcript already overuses chips, pills, and accent markers.

A flatter lane should generally replace:

- chip clusters
- action chips
- status chips inside row cards

with clearer rows, stronger typography, and fewer emphasis signals.

## Verification Strategy

Because this work changes the visible hierarchy of nearly every transcript
state, verification should prove both structural correctness and runtime safety.

### Required verification

1. widget tests for representative transcript classes
- message
- annotation
- blocker
- divider

2. tests that ensure blockers remain visible/actionable in pinned and unpinned
   placements

3. tests that ensure resolved items downgrade visually or structurally from
   blocking states where intended

4. manual runtime verification in the live lane for:
- streaming assistant output
- reasoning while running
- approval required
- user input required
- changed files after a tool action
- work log accumulation
- SSH failure/trust prompts

### What to verify specifically

- no nested bordered panel remains inside transcript blockers unless explicitly
  justified
- annotation items do not use `PocketTranscriptFrame`
- flat annotations remain readable in both light and dark themes
- blocker items remain visually distinct from annotations
- transcript spacing reads as one lane, not independent cards with gaps

## Recommended First Implementation Slice

The safest first code slice is:

1. add the new flat transcript primitives
2. migrate `ReasoningCard`
3. migrate `StatusCard`
4. migrate `ErrorCard`
5. migrate `PlanUpdateCard`

Why this slice:

- it exercises the new annotation model
- it removes several framed items quickly
- it avoids blocker complexity at the start
- it reveals whether the typography and spacing direction is actually strong
  enough before rewriting the densest families

## Final Recommendation

The transcript should be redesigned around one simple rule:

the lane is the surface, and transcript items are mostly content.

Only blockers earn a container.

Everything else should rely on rhythm, type, alignment, and restrained inline
emphasis.

That is the correct direction if the goal is to make the lane feel flatter,
calmer, and more professional without disconnecting it from the real Codex
runtime semantics.
