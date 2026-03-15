# Transcript Immutability Migration Plan

## Status

This document records the transcript design correction that is still required
after several incomplete or incorrect fixes.

The core product requirement is now explicit:

- once something is on the timeline, it must never change again
- chronology must stay readable from top to bottom
- only the active tail may mutate, and only while it is still the same
  contiguous live artifact

This plan exists because previous fixes were too local and treated individual
symptoms instead of the ownership model.

## Reference Interpretation

The local reference Codex clone is:

- `.reference/codex`

Important reference findings:

- plan updates are append-only visible history in the TUI
- file changes are shown as discrete visible artifacts in transcript history
- `turn/diff/updated` is an authoritative turn-level aggregate snapshot, not
  proof that the visible transcript should collapse into one mutable card
- Codex separates live/in-flight behavior from committed history more strongly
  than the current Pocket Relay reducer/state model

Relevant reference paths:

- `.reference/codex/codex-rs/tui/src/chatwidget.rs`
- `.reference/codex/codex-rs/tui/src/history_cell.rs`
- `.reference/codex/codex-rs/tui/src/diff_render.rs`
- `.reference/codex/codex-rs/app-server/README.md`

## What Went Wrong

The repeated failure pattern was:

1. identify one visible symptom
2. patch the nearest reducer or transcript card path
3. preserve the underlying mutable timeline model
4. pass tests that only prove the patch, not the real contract

That produced multiple wrong fixes:

- treating `turn/diff/updated` as the owner of the visible changed-files card
- allowing committed history to be rewritten via upsert semantics
- deriving transcript order by sorting mixed committed and live content
- validating protocol/state correctness while missing transcript chronology

The result is a transcript that behaves more like a mutable dashboard than a
permanent event history.

## Non-Negotiable Contract

These are the target semantics.

### 1. Committed history is immutable

Once a block is committed to the timeline:

- its content does not change
- its relative position does not change
- it is never replaced in place
- later events may add new blocks, but may not rewrite old ones

### 2. Only the live tail may mutate

There is one allowed exception:

- the currently active tail card may change while it is still the same
  contiguous live artifact

That means:

- repeated deltas for the same still-live artifact may update the tail
- if a different artifact appears, the previous tail is frozen forever
- if the same item type resumes later, it gets a new card

### 3. Aggregate snapshots are state, not timeline owners

Events like `turn/diff/updated` may update turn state, but they must not own or
rewrite committed history.

### 4. The past should preserve reading order

The transcript must reflect chronological arrival order, not a re-sorted view
computed from mixed state.

## Current Mutation Seams

These are the concrete code paths that currently violate or weaken the target
contract.

### Committed history mutation

- [`lib/src/features/chat/application/transcript_policy_support.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_policy_support.dart)
  `upsertBlock()` replaces already committed blocks by id.

### Transcript built from mixed committed + live state

- [`lib/src/features/chat/models/codex_session_state.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/models/codex_session_state.dart)
  `transcriptBlocks` combines committed `blocks` with projected `activeTurn`
  segments.
- That same file sorts the final transcript by `createdAt`, which means order is
  reconstructed instead of preserved.

### Active-turn mutation by stable item identity

- [`lib/src/features/chat/application/transcript_turn_segmenter.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_turn_segmenter.dart)
  `upsertItem()` mutates one segment per item id.

### Committing active-turn content by upsert

- [`lib/src/features/chat/application/transcript_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_policy.dart)
  `_commitActiveTurn()` projects live segments and upserts them into committed
  history.

### Mutable turn-level changed-files ownership

- [`lib/src/features/chat/application/transcript_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_policy.dart)
  `applyTurnDiffUpdated()` creates one stable changed-files block per turn id,
  causing visible accumulation into a single mutable card.

### Committed local-echo user message reconciliation

- [`lib/src/features/chat/application/transcript_item_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_item_policy.dart)
  `_reconcileCommittedUserMessageBlocks()` mutates already committed user
  message blocks.

## Design Direction

The architecture should be split into two explicit ownership domains.

### A. Committed timeline history

Properties:

- append-only
- arrival-order preserving
- immutable after commit
- directly rendered as transcript history

Suggested shape:

- `committedBlocks: List<CodexUiBlock>`

### B. Live tail state

Properties:

- mutable
- transient
- bounded to the active turn
- not part of committed history until frozen/committed

Suggested shape:

- `activeTurn.liveSegments`
- optional turn snapshots such as current diff snapshot, pending usage snapshot,
  pending approvals, pending input

The transcript surface should render:

- committed immutable history
- followed by projected live tail blocks

No sort pass should reorder that final list.

## Edge Cases That Must Be Supported

The next implementation must handle these explicitly.

### Repeating deltas for the same live artifact

Allowed:

- the tail mutates while the artifact is still contiguous and active

Not allowed:

- an old card higher in history changes after later cards exist

### Same item resumes after interruption

If the same item continues after another visible artifact appears:

- the previous visible card is frozen
- the resumed output starts a new visible card

### Turn-level diff snapshots

`turn/diff/updated` may still matter for:

- authoritative current turn state
- detail sheets
- internal reconciliation

But it must not rewrite visible file-change history.

### Pending requests

Pending approvals and user input are live workflow state, not committed history.
Their eventual resolution should append immutable history artifacts.

### Local-echo user messages

The optimistic local echo should not be rewritten after commit. Provider linkage
must be tracked outside the committed block itself.

## Five Commit Migration Plan

This work should be executed as five separate commits so progress and mistakes
are easy to inspect and revert.

### Commit 1: Lock The Contract In Tests

Goal:

- make the intended behavior executable before changing state ownership

Changes:

- add reducer tests that prove committed blocks never mutate
- add widget tests that prove chronology is preserved
- add tests that prove only the live tail may mutate
- add tests that prove `turn/diff/updated` does not own visible transcript
  history
- replace existing tests that currently lock in the wrong changed-files
  convergence behavior

Required failing cases to encode:

- past changed-files cards must not merge into one mutable card
- past plan cards must not change
- resumed same-item output after an interruption must create a new card

Exit criterion:

- tests fail on current implementation for the right reasons

### Commit 2: Split Committed History From Live Tail State

Goal:

- make the ownership model explicit

Changes:

- refactor `CodexSessionState` so committed history and live tail state are
  stored separately
- remove transcript construction that mixes committed blocks and live segments
  and then sorts them
- make `transcriptBlocks` render committed history first and live tail second

Primary files:

- [`lib/src/features/chat/models/codex_session_state.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/models/codex_session_state.dart)
- [`lib/src/features/chat/application/transcript_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_policy.dart)

Exit criterion:

- the state model can express immutable history plus mutable tail separately

### Commit 3: Remove Aggregate Snapshot Ownership From Timeline

Goal:

- stop `turn/diff/updated` from owning visible changed-files history

Changes:

- move turn diff handling to live turn snapshot state only
- keep visible changed-files transcript ownership on file-change item artifacts
- ensure plan updates remain append-only
- ensure turn snapshots can still power any detail views without mutating
  committed history

Primary files:

- [`lib/src/features/chat/application/transcript_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_policy.dart)
- [`lib/src/features/chat/application/transcript_changed_files_parser.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_changed_files_parser.dart)

Exit criterion:

- no visible transcript card is rewritten by `turn/diff/updated`

### Commit 4: Replace Stable Item Upserts With Live Artifact Instances

Goal:

- implement the “only the active tail may mutate” rule

Changes:

- stop treating one `itemId` as one permanently mutable visible segment
- introduce live artifact instances representing one contiguous visible run
- mutate only the last active instance while it stays contiguous
- freeze and fork a new instance when another visible artifact interrupts the
  stream

Primary files:

- [`lib/src/features/chat/application/transcript_turn_segmenter.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_turn_segmenter.dart)
- [`lib/src/features/chat/application/transcript_item_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_item_policy.dart)

Exit criterion:

- the same item can create multiple immutable visible artifacts over time

### Commit 5: Finalize Commit Semantics And Remove Legacy Mutation Paths

Goal:

- make append-only history the only transcript model left in the codebase

Changes:

- change active-turn commit to append frozen blocks in order
- remove committed-history `upsertBlock()` call sites for transcript ownership
- remove committed user-message reconciliation
- keep pending request workflow state off-timeline until resolution
- clean out obsolete helper paths and incorrect tests
- update handoff docs after behavior is verified

Primary files:

- [`lib/src/features/chat/application/transcript_policy_support.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_policy_support.dart)
- [`lib/src/features/chat/application/transcript_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_policy.dart)
- [`lib/src/features/chat/application/transcript_item_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_item_policy.dart)
- [`lib/src/features/chat/application/transcript_request_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_request_policy.dart)

Exit criterion:

- committed history is append-only by construction

## Verification Requirements

Each commit in the migration must end with:

- `dart analyze`
- focused reducer tests for the changed invariant
- focused widget tests for the visible transcript behavior

Additional runtime verification is required after commits 3 through 5:

- emulator check for repeated plan updates
- emulator check for sequential file changes
- emulator check for interrupted and resumed same-item output
- emulator check for approval/input request resolution history

## Definition Of Done

The migration is only done when all of the following are true:

- committed timeline blocks never mutate after commit
- transcript order matches event arrival order
- only the live tail may mutate
- repeated file changes no longer collapse into one mutable “all changes so far”
  card
- `turn/diff/updated` no longer owns visible timeline artifacts
- the reducer and widget tests prove those semantics directly

## Immediate Next Read

The next agent working on transcript parity should read this document before
touching transcript reducers again.
