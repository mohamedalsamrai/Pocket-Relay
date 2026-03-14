# Large File Bug Triage

This note tracks the current tracked files over 500 LOC and classifies them for bug-fix work.

The goal is not "refactor everything now." The goal is to know which large files are likely bug magnets and which ones are mostly noise while we focus on fixing behavior first.

Counts below are from the current workspace snapshot and will drift over time.

## Fix Bugs First In These Files

| LOC | File | Why it matters |
| ---: | --- | --- |
| 1767 | `lib/src/features/chat/presentation/widgets/conversation_entry_card.dart` | Huge rendering surface with many card variants, theme branches, and conditional UI paths. High regression risk. |
| 1355 | `lib/src/features/chat/services/codex_session_reducer.dart` | Central transcript state machine. Small logic bugs here usually show up everywhere. |
| 1290 | `lib/src/features/chat/services/codex_runtime_event_mapper.dart` | Protocol mapping layer. Missing cases or bad normalization here turn into silent UI bugs. |
| 929 | `lib/src/features/chat/services/codex_app_server_client.dart` | Transport and request/response plumbing. Breakage here causes session, approval, and runtime failures. |
| 755 | `lib/src/features/chat/presentation/chat_screen.dart` | Top-level screen orchestration, event routing, connection flow, and action handling. |
| 508 | `lib/src/features/settings/presentation/connection_sheet.dart` | Large form with persistence and validation behavior. Worth touching when a settings bug lands here. |
| 507 | `lib/src/features/chat/models/codex_runtime_event.dart` | Large protocol model surface. Not a direct bug hotspot by itself, but it is growing enough that mistakes become easier. |

## Usually Ignore During Bug Triage

| LOC | File | Why it is lower priority |
| ---: | --- | --- |
| 935 | `test/codex_app_server_client_test.dart` | Big, but test-only. Important for coverage, not a production bug source. |
| 705 | `macos/Runner.xcodeproj/project.pbxproj` | Generated Xcode project metadata. Only touch when fixing platform build/config issues. |
| 620 | `ios/Runner.xcodeproj/project.pbxproj` | Same as macOS project metadata. |
| 578 | `pubspec.lock` | Dependency lockfile. Not a refactor target. |

## Practical Rule

When a bug report comes in:

1. Check `codex_runtime_event_mapper.dart`, `codex_session_reducer.dart`, and `chat_screen.dart` first for transcript/runtime issues.
2. Check `codex_app_server_client.dart` first for connection, approval, request, or session bugs.
3. Check `conversation_entry_card.dart` first for rendering, spacing, theming, or card-specific UI bugs.
4. Only touch `project.pbxproj` files or `pubspec.lock` if the bug is explicitly platform/build/dependency related.

## Refactor Later, Not Now

When the bug backlog is calmer, the best split candidates are:

- `codex_runtime_event_mapper.dart`: split by transport type, item mapping, request mapping, and notification helpers.
- `codex_session_reducer.dart`: split reducer logic from block-construction helpers.
- `conversation_entry_card.dart`: split by card family instead of keeping every visual variant in one file.
- `codex_app_server_client.dart`: split JSON-RPC transport, request helpers, and SSH process bootstrap.
