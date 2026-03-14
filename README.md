# Codex Pocket

Codex Pocket is a Flutter app that SSHes into a developer box, runs the Codex CLI remotely in `--json` mode, and renders the stream as mobile-friendly cards instead of a raw terminal.

## Source Tree

```text
lib/
  main.dart
  src/
    app.dart
    core/
      models/
        connection_models.dart
      storage/
        codex_profile_store.dart
      utils/
        shell_utils.dart
        thread_utils.dart
    features/
      chat/
        models/
          codex_remote_event.dart
          conversation_entry.dart
        presentation/
          chat_screen.dart
          widgets/
            chat_composer.dart
            connection_banner.dart
            conversation_entry_card.dart
            empty_state.dart
        services/
          codex_event_parser.dart
          ssh_codex_service.dart
      settings/
        presentation/
          connection_sheet.dart
test/
  codex_event_parser_test.dart
  widget_test.dart
```

## What It Does

- Stores SSH connection settings locally and keeps secrets in secure storage.
- Starts or resumes remote Codex sessions over SSH.
- Parses Codex JSONL output into cards for assistant messages, commands, status, errors, and usage.
- Keeps the UI optimized for phone-sized screens.

## Run It

```bash
flutter pub get
flutter run
```

The Android app needs network access and expects the remote box to already have the `codex` CLI installed and authenticated.
