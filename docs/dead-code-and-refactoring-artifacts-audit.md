# Dead Code And Refactoring Artifacts Audit

Date: 2026-03-15

## Purpose

This document records confirmed dead code, compatibility residue, facade-only
APIs, duplicated ownership, and parallel code paths that now overlap in the
current Pocket Relay codebase.

This is an audit document, not a cleanup plan. The goal is to describe what is
actually present today and why it looks like refactoring residue.

## Cleanup Buckets

### Group 1: Safe Quick Deletions

Status: completed on 2026-03-15

Completed items:

- removed `CodexRuntimeEventMapper.bind()`
- removed `ChatSessionController.hasVisibleConversation`
- removed `lib/src/core/utils/thread_utils.dart`
- removed the unused `TranscriptChangedFilesParser` dependency injection seam
- removed the dead conditional branch in
  `_mergeResolvedRequestBlocks()`

### Group 2: Medium Cleanups

Status: in progress on 2026-03-15

Completed items:

- replaced permanent legacy-key fallback with a converging migration that
  copies legacy profile and secret keys forward, then removes the legacy keys
- removed the dead `skipGitRepoCheck` setting from the profile model and
  settings UI
- removed unused `CodexAppServerClient` facade methods
  `resolvePermissionsRequest(...)` and `sendServerResult(...)`
- removed unused `latestUsageSummary` from `CodexActiveTurnState`
- updated `README.md` to reflect the current app-server-only architecture

Scope:

- continue trimming write-only state that no longer affects runtime behavior
- continue removing dead transport residue that is still compiled and tested
- repair any remaining stale docs tied to those areas

### Group 3: Structural Refactors

Status: completed on 2026-03-15

Completed items:

- removed the dead pre-artifact `TranscriptItemBlockFactory.blockFromActiveItem(...)`
  path and its test-only coverage
- removed the leftover `CodexCommandExecutionBlock`,
  `CodexWorkLogEntryBlock`, and `CommandCard` shim path
- collapsed active-turn bootstrap into shared `TranscriptPolicySupport`
  helpers so reducer, item policy, request policy, and transcript policy no
  longer each build turn state separately
- moved thread and turn start ownership to runtime notifications instead of
  synthesizing duplicate start events from controller responses
- centralized request titles and question/answer summaries so pending overlays
  and resolved transcript entries share one string owner

Scope:
- keep the structural ownership model converged as follow-up cleanup lands

## Verification

- `dart analyze` reports no errors after the current structural pass.
- The full test suite passed after the current structural pass.
- All other findings were confirmed by direct call-site tracing with `rg`.

## Remaining Findings

### Medium

#### 1. `CodexActiveTurnState` still contains write-only refactor residue

Several fields are still present in state but are not read by app code.

Fields:

- `turnDiffSnapshot`
- `hasWork`
- `hasReasoning`

Evidence:

- [`lib/src/features/chat/models/codex_session_state.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/models/codex_session_state.dart#L721)
- [`lib/src/features/chat/application/transcript_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_policy.dart#L322)
- [`lib/src/features/chat/application/transcript_turn_segmenter.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_turn_segmenter.dart#L57)

Why this matters:

- these fields still shape the model layer
- production behavior no longer depends on them
- tests currently preserve some of this state shape

#### 2. Auth-refresh response path is dead in the shipped app

The transport layer still implements `respondAuthTokensRefresh(...)`, but the
controller rejects auth-refresh requests as unsupported before that path can be
used.

Evidence:

- [`lib/src/features/chat/infrastructure/app_server/codex_app_server_client.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_client.dart#L102)
- [`lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart#L177)
- [`lib/src/features/chat/application/chat_session_controller.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/chat_session_controller.dart#L225)

Why this matters:

- this is facade surface with no reachable production path
- transport and controller disagree about supported behavior

#### 3. `item/fileRead/requestApproval` has split ownership

The request API still knows how to resolve file-read approvals, but the
controller treats the request as legacy and rejects it before resolution can be
used.

Evidence:

- [`lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart#L201)
- [`lib/src/features/chat/application/chat_session_controller.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/chat_session_controller.dart#L249)

Why this matters:

- this is split behavior for the same protocol surface
- only the rejection path is reachable in production
