import 'dart:convert';
import 'dart:io';

import 'capture_options.dart';

final class ResolvedCaptureContext {
  const ResolvedCaptureContext({
    required this.threadId,
    required this.workingDirectory,
    required this.codexPath,
  });

  final String threadId;
  final String workingDirectory;
  final String codexPath;
}

Future<ResolvedCaptureContext> resolveCaptureContext(
  CaptureOptions options,
) async {
  final prefs = await _loadPreferences(options.prefsPath);
  final profile = _loadProfile(prefs, profileKey: options.profileKey);
  final threadId = _resolveThreadId(prefs, options: options);
  final workingDirectory =
      options.workingDirectory ?? _asNonEmptyString(profile['workspaceDir']);
  final codexPath =
      options.launcherCommand ?? _asNonEmptyString(profile['codexPath']);
  final connectionMode = (_asString(profile['connectionMode']) ?? '').trim();

  if (workingDirectory == null || workingDirectory.isEmpty) {
    throw const FormatException(
      'Saved profile did not include a usable workspace directory. '
      'Pass --working-directory explicitly.',
    );
  }

  if (codexPath == null || codexPath.isEmpty) {
    throw const FormatException(
      'Saved profile did not include a usable Codex launch command. '
      'Pass --launcher-command explicitly.',
    );
  }

  if (options.launcherCommand == null &&
      connectionMode.isNotEmpty &&
      connectionMode != 'local') {
    throw FormatException(
      'Saved profile is "$connectionMode", but this capture tool only launches '
      'a local app-server process. Pass --launcher-command and '
      '--working-directory explicitly if you have a local repro path.',
    );
  }

  return ResolvedCaptureContext(
    threadId: threadId,
    workingDirectory: workingDirectory,
    codexPath: codexPath,
  );
}

Future<Map<String, dynamic>> _loadPreferences(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    throw StateError('Shared preferences file not found: $path');
  }
  final text = await file.readAsString();
  final decoded = jsonDecode(text);
  if (decoded is! Map) {
    throw StateError('Shared preferences file was not a JSON object.');
  }
  return Map<String, dynamic>.from(decoded);
}

Map<String, dynamic> _loadProfile(
  Map<String, dynamic> prefs, {
  required String profileKey,
}) {
  final rawProfile = prefs[profileKey];
  if (rawProfile is! String || rawProfile.trim().isEmpty) {
    throw StateError(
      'Shared preferences did not include a profile at $profileKey.',
    );
  }
  final decoded = jsonDecode(rawProfile);
  if (decoded is! Map) {
    throw StateError('Saved profile at $profileKey was not a JSON object.');
  }
  return Map<String, dynamic>.from(decoded);
}

String _resolveThreadId(
  Map<String, dynamic> prefs, {
  required CaptureOptions options,
}) {
  if (options.threadId case final threadId?) {
    return threadId;
  }

  final rawHandoff = prefs[options.handoffKey];
  if (rawHandoff is! String || rawHandoff.trim().isEmpty) {
    throw StateError(
      'Shared preferences did not include a handoff entry at ${options.handoffKey}. '
      'Pass --thread-id explicitly.',
    );
  }

  final decoded = jsonDecode(rawHandoff);
  if (decoded is! Map) {
    throw StateError(
      'Saved handoff at ${options.handoffKey} was not a JSON object. '
      'Pass --thread-id explicitly.',
    );
  }

  final resumeThreadId = _asNonEmptyString(
    Map<String, dynamic>.from(decoded)['resumeThreadId'],
  );
  if (resumeThreadId == null) {
    throw StateError(
      'Handoff entry at ${options.handoffKey} did not include a resumeThreadId. '
      'Pass --thread-id explicitly.',
    );
  }

  return resumeThreadId;
}

String? _asString(Object? value) {
  return value is String ? value : null;
}

String? _asNonEmptyString(Object? value) {
  final normalized = _asString(value)?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}
