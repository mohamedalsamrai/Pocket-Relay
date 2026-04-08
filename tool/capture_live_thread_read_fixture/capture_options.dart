import 'dart:io';

final class CaptureOptions {
  const CaptureOptions({
    required this.prefsPath,
    required this.profileKey,
    required this.handoffKey,
    required this.threadId,
    required this.launcherCommand,
    required this.workingDirectory,
    required this.initializeTimeoutSeconds,
    required this.readTimeoutSeconds,
    required this.sanitizedOutputPath,
    required this.rawOutputPath,
  });

  final String prefsPath;
  final String profileKey;
  final String handoffKey;
  final String? threadId;
  final String? launcherCommand;
  final String? workingDirectory;
  final int initializeTimeoutSeconds;
  final int readTimeoutSeconds;
  final String sanitizedOutputPath;
  final String? rawOutputPath;

  static CaptureOptions? parse(List<String> args) {
    var prefsPath =
        '${Platform.environment['HOME']}/.local/share/com.example.pocket_relay/shared_preferences.json';
    var profileKey = 'pocket_relay.profile';
    var handoffKey = 'pocket_relay.conversation_handoff';
    String? threadId;
    String? launcherCommand;
    String? workingDirectory;
    var initializeTimeoutSeconds = 90;
    var readTimeoutSeconds = 60;
    String? sanitizedOutputPath;
    String? rawOutputPath;

    for (var index = 0; index < args.length; index += 1) {
      final arg = args[index];
      switch (arg) {
        case '--prefs':
          if (index + 1 >= args.length) {
            return null;
          }
          prefsPath = args[++index];
        case '--profile-key':
          if (index + 1 >= args.length) {
            return null;
          }
          profileKey = args[++index];
        case '--handoff-key':
          if (index + 1 >= args.length) {
            return null;
          }
          handoffKey = args[++index];
        case '--thread-id':
          if (index + 1 >= args.length) {
            return null;
          }
          threadId = args[++index];
        case '--launcher-command':
          if (index + 1 >= args.length) {
            return null;
          }
          launcherCommand = args[++index];
        case '--working-directory':
          if (index + 1 >= args.length) {
            return null;
          }
          workingDirectory = args[++index];
        case '--initialize-timeout-seconds':
          if (index + 1 >= args.length) {
            return null;
          }
          initializeTimeoutSeconds = int.parse(args[++index]);
        case '--read-timeout-seconds':
          if (index + 1 >= args.length) {
            return null;
          }
          readTimeoutSeconds = int.parse(args[++index]);
        case '--sanitized-output':
          if (index + 1 >= args.length) {
            return null;
          }
          sanitizedOutputPath = args[++index];
        case '--raw-output':
          if (index + 1 >= args.length) {
            return null;
          }
          rawOutputPath = args[++index];
        case '--help':
        case '-h':
          return null;
        default:
          return null;
      }
    }

    final normalizedSanitizedOutputPath = sanitizedOutputPath?.trim();
    if (normalizedSanitizedOutputPath == null ||
        normalizedSanitizedOutputPath.isEmpty) {
      return null;
    }

    return CaptureOptions(
      prefsPath: prefsPath,
      profileKey: profileKey,
      handoffKey: handoffKey,
      threadId: _normalizeOptionalString(threadId),
      launcherCommand: _normalizeOptionalString(launcherCommand),
      workingDirectory: _normalizeOptionalString(workingDirectory),
      initializeTimeoutSeconds: initializeTimeoutSeconds,
      readTimeoutSeconds: readTimeoutSeconds,
      sanitizedOutputPath: normalizedSanitizedOutputPath,
      rawOutputPath: _normalizeOptionalString(rawOutputPath),
    );
  }
}

String? _normalizeOptionalString(String? value) {
  if (value == null) {
    return null;
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

void printCaptureUsage(IOSink sink) {
  sink.writeln(
    'Usage: dart run tool/capture_live_thread_read_fixture.dart '
    '--sanitized-output <fixture.json> [--raw-output <raw.json>] '
    '[--thread-id <thread_id>] [--prefs <shared_preferences.json>] '
    '[--profile-key <key>] [--handoff-key <key>] '
    '[--launcher-command <command>] [--working-directory <dir>] '
    '[--initialize-timeout-seconds <seconds>] '
    '[--read-timeout-seconds <seconds>]',
  );
}
