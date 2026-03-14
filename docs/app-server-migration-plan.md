# Codex App-Server Migration Plan

## Goal

Migrate Codex Pocket from `codex exec --json` to `codex app-server` so the app can:

- render richer Codex output as mobile widgets
- handle mid-turn approvals and user-input requests
- keep a long-lived bidirectional session over SSH
- decouple UI widgets from raw Codex protocol messages

This plan is intentionally narrow. The target is a phone-friendly Codex client, not a full clone of T3 Code.

## Why This Migration Is Worth Doing

The current implementation is built around a one-shot command runner:

- `lib/src/features/chat/services/ssh_codex_service.dart`
- `lib/src/features/chat/services/codex_event_parser.dart`
- `lib/src/features/chat/presentation/chat_screen.dart`

That shape works for `codex exec --json`, but it has hard limits:

- it assumes one command per turn
- it assumes stdout is the only meaningful stream
- it treats Codex as a producer, not a peer
- it cannot support mid-turn approvals or structured user-input requests cleanly
- it pushes raw transport concerns too close to the UI

`codex app-server` is the better fit because the app needs bidirectional interaction, not just transcript streaming.

## Non-Goals

Do not pull in the full reference architecture.

Out of scope for this migration:

- multi-project orchestration
- server-side storage
- web parity with the reference repo
- background sync
- local execution of Codex on-device

## Target Architecture

The target architecture should be:

```text
SSH stdio transport
  -> JSON-RPC message codec
  -> canonical runtime event mapper
  -> chat session state
  -> widget view models
  -> Flutter widgets
```

The most important boundary is:

```text
raw app-server message -> canonical Dart event -> UI state/widget model
```

The widgets must never depend directly on raw JSON-RPC method names.

## Proposed File Layout

Add these new files:

```text
lib/src/features/chat/models/codex_runtime_event.dart
lib/src/features/chat/models/codex_session_state.dart
lib/src/features/chat/models/codex_ui_block.dart
lib/src/features/chat/services/codex_app_server_client.dart
lib/src/features/chat/services/codex_json_rpc_codec.dart
lib/src/features/chat/services/codex_runtime_event_mapper.dart
lib/src/features/chat/services/codex_session_reducer.dart
test/codex_runtime_event_mapper_test.dart
test/codex_session_reducer_test.dart
```

Modify these existing files:

```text
lib/src/features/chat/models/conversation_entry.dart
lib/src/features/chat/presentation/chat_screen.dart
lib/src/features/chat/presentation/widgets/conversation_entry_card.dart
lib/src/features/chat/services/ssh_codex_service.dart
```

Keep these temporarily during migration:

```text
lib/src/features/chat/models/codex_remote_event.dart
lib/src/features/chat/services/codex_event_parser.dart
```

Delete or retire them only after app-server is stable in the app.

## Phase 1: Introduce A Long-Lived App-Server Client

### Objective

Replace the current "run a command and wait for exit" flow with a persistent SSH session that launches:

```bash
codex app-server --listen stdio://
```

### Implementation

Create `codex_app_server_client.dart` with a small session-oriented API:

```dart
abstract class CodexAppServerClient {
  Stream<CodexRuntimeEvent> get events;

  Future<void> connect({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  });

  Future<void> startSession({
    required String cwd,
    String? model,
  });

  Future<void> sendUserMessage({
    required String threadId,
    required String text,
  });

  Future<void> answerUserInput({
    required String requestId,
    required List<String> answers,
  });

  Future<void> resolveApproval({
    required String requestId,
    required bool approved,
  });

  Future<void> abortTurn();
  Future<void> disconnect();
}
```

### Notes

- keep using `dartssh2`
- launch one SSH process and keep it open
- read stdout line-by-line
- decode every line as JSON-RPC
- write JSON-RPC requests to remote stdin
- treat stderr as diagnostics, not transcript content

### Deliverable

By the end of Phase 1, the app can establish and maintain a remote `app-server` session over SSH.

## Phase 2: Add A JSON-RPC Codec Layer

### Objective

Stop parsing raw JSON as anonymous maps inside business logic.

### Implementation

Create `codex_json_rpc_codec.dart` to:

- decode incoming JSON lines into typed message classes
- encode outgoing requests and notifications
- track request ids for request/response matching

Use a minimal model:

```dart
sealed class CodexJsonRpcMessage {}

final class CodexJsonRpcRequest extends CodexJsonRpcMessage {}
final class CodexJsonRpcNotification extends CodexJsonRpcMessage {}
final class CodexJsonRpcResponse extends CodexJsonRpcMessage {}
```

### Required Behavior

- assign monotonically increasing local request ids
- maintain a pending-request map
- surface malformed messages as runtime warnings, not crashes
- preserve the raw payload for debugging

### Deliverable

By the end of Phase 2, the transport layer knows JSON-RPC, and nothing above it needs to parse wire-format details manually.

## Phase 3: Introduce Canonical Runtime Events

### Objective

Mirror the reference repo's strongest idea: normalize protocol messages into a stable internal event vocabulary.

### Implementation

Create `codex_runtime_event.dart` with a narrow but useful union. Start with these event types:

- `sessionStarted`
- `sessionStateChanged`
- `sessionExited`
- `threadStarted`
- `threadStateChanged`
- `turnStarted`
- `turnCompleted`
- `turnAborted`
- `itemStarted`
- `itemUpdated`
- `itemCompleted`
- `contentDelta`
- `requestOpened`
- `requestResolved`
- `userInputRequested`
- `userInputResolved`
- `runtimeWarning`
- `runtimeError`

Also define normalized enums:

- `CanonicalItemType`
- `CanonicalRequestType`
- `RuntimeContentStreamKind`

### Initial Raw Methods To Map

Map these app-server methods first:

- `session/connecting`
- `session/ready`
- `session/started`
- `session/exited`
- `session/closed`
- `thread/started`
- `thread/status/changed`
- `turn/started`
- `turn/completed`
- `turn/aborted`
- `item/started`
- `item/completed`
- `item/agentMessage/delta`
- `item/reasoning/textDelta`
- `item/reasoning/summaryTextDelta`
- `item/commandExecution/outputDelta`
- `item/fileChange/outputDelta`
- `item/tool/requestUserInput`
- `item/tool/requestUserInput/answered`
- approval-related request methods
- `serverRequest/resolved`
- `error`
- `configWarning`
- `deprecationNotice`

### Mapping Rules

- unknown methods should be logged as debug/status events, not rendered as conversation cards
- item types should be normalized into stable values such as `assistantMessage`, `reasoning`, `plan`, `commandExecution`, `fileChange`, `unknown`
- request types should be normalized into stable values such as `commandExecutionApproval`, `fileReadApproval`, `fileChangeApproval`, `toolUserInput`, `unknown`
- text deltas should update existing in-progress items rather than append new cards every time

### Deliverable

By the end of Phase 3, the app can consume app-server messages without exposing protocol method names to the UI.

## Phase 4: Add A Session Reducer

### Objective

Move state transitions out of `ChatScreen`.

### Implementation

Create `codex_session_state.dart` and `codex_session_reducer.dart`.

`CodexSessionState` should own:

- connection status
- current thread id
- current turn id
- pending approval requests
- pending user-input requests
- active items by item id
- rendered transcript blocks
- latest usage summary

The reducer should consume `CodexRuntimeEvent` values and produce the next state.

### Rules

- `contentDelta` updates the current block for the matching item id
- `itemCompleted` finalizes the block and clears its running state
- `requestOpened` creates an actionable approval block
- `userInputRequested` creates an actionable input block
- `requestResolved` and `userInputResolved` mark those blocks as completed
- warnings and errors become status blocks, not crashes

### Deliverable

By the end of Phase 4, `ChatScreen` becomes a thin view over session state instead of the owner of protocol logic.

## Phase 5: Replace Conversation Entries With UI Blocks

### Objective

Stop forcing all protocol output into the current `ConversationEntry` shape.

### Implementation

Create `codex_ui_block.dart` and migrate the UI to a richer render model. At minimum support these block kinds:

- user message
- assistant message
- reasoning
- plan
- command execution
- file change
- approval request
- user-input request
- status
- error
- usage

The existing `ConversationEntry` model is too flat for this. It should either be extended heavily or replaced with `CodexUiBlock`.

### Widget Changes

Update `conversation_entry_card.dart` or replace it with block-specific rendering:

- assistant and reasoning blocks use markdown/text rendering
- command execution blocks show command, streaming output, running/completed state, and exit code
- approval request blocks show approve/deny actions
- user-input request blocks show one or more input fields and a submit action
- status and error blocks remain compact

### Deliverable

By the end of Phase 5, all important Codex interactions can be rendered as dedicated widgets instead of generic cards.

## Phase 6: Integrate ChatScreen With App-Server

### Objective

Switch the screen from "send one prompt, subscribe until done" to "connect once, then drive a session".

### Implementation

Refactor `chat_screen.dart` so it:

- connects to the app-server client when the profile is ready
- starts or resumes a session once
- sends user messages as JSON-RPC requests
- listens to canonical runtime events
- binds approve/deny buttons to `resolveApproval(...)`
- binds user-input widgets to `answerUserInput(...)`
- uses local state only for view concerns such as text editing and scrolling

### Important Behavior Changes

- `_isBusy` should no longer mean "remote process exists"
- the screen should support waiting states where Codex is idle but the session is still alive
- stopping a turn is different from disconnecting the session

### Deliverable

By the end of Phase 6, the screen behaves like a live client session instead of a one-shot command launcher.

## Phase 7: Keep Exec As A Temporary Fallback

### Objective

Reduce migration risk.

### Implementation

Keep the current `exec --json` path behind a temporary feature flag or profile option while app-server stabilizes.

Suggested temporary profile option:

```text
transportMode = execJson | appServer
```

Default new users to `appServer` once the app-server path works end-to-end.

Remove `execJson` only after:

- the app-server path can start a thread
- the app-server path can render assistant output
- the app-server path can handle one approval flow
- the app-server path can handle one user-input flow

## Testing Plan

Add tests in layers.

### Mapper Tests

`test/codex_runtime_event_mapper_test.dart`

Cover:

- session lifecycle mapping
- thread lifecycle mapping
- assistant message deltas
- reasoning deltas
- command output deltas
- file change output deltas
- approval requests
- user-input requests
- error and warning mapping
- unknown method handling

### Reducer Tests

`test/codex_session_reducer_test.dart`

Cover:

- creating and updating assistant blocks from deltas
- finalizing running items
- opening and resolving approval blocks
- opening and resolving user-input blocks
- updating thread and turn ids
- keeping errors non-fatal to the UI

### Widget Tests

Expand `test/widget_test.dart` or replace it with focused widget tests for:

- assistant block rendering
- running command block rendering
- approval request widget behavior
- user-input request widget behavior

## Acceptance Criteria

The migration is complete when all of these are true:

1. The app launches `codex app-server --listen stdio://` over SSH and keeps the session open.
2. A user can send multiple prompts within one connected session.
3. Assistant text streams into a live widget without creating duplicate cards per delta.
4. Command execution output streams into a dedicated widget.
5. A mid-turn approval request is shown as an actionable widget and can be resolved from the phone.
6. A mid-turn user-input request is shown as an actionable widget and can be answered from the phone.
7. Unknown protocol messages do not crash the app.
8. The UI consumes only canonical runtime events or UI blocks, never raw JSON-RPC maps.

## Recommended Execution Order

Build in this order:

1. app-server SSH client
2. JSON-RPC codec
3. canonical runtime event mapper
4. session reducer
5. assistant/command/status widgets
6. approval and user-input widgets
7. ChatScreen integration
8. fallback cleanup

This order keeps the transport and state boundaries stable before touching the UI heavily.

## Decision Summary

The migration should copy the reference repo's protocol boundary, not its whole product architecture.

Copy this:

- app-server over a bidirectional transport
- canonical runtime events
- reducer-style state updates
- request and user-input handling as first-class events

Do not copy this:

- server-side orchestration layers
- multi-project complexity
- full web app assumptions

The app only needs a small, durable client architecture that can turn Codex events into useful phone widgets.
