import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';

const String retainedOutputStateKey = 'retainedOutputState';
const String retainedOutputStateEmpty = 'empty';
const String retainedOutputStateUncaptured = 'uncaptured';

abstract final class TranscriptCommandAuditSnapshot {
  static const String aggregatedOutputKey = 'aggregatedOutput';

  static Map<String, dynamic>? mergeLifecycleSnapshot(
    Map<String, dynamic>? eventSnapshot,
    Map<String, dynamic>? existingSnapshot, {
    required String rawMethod,
    required TranscriptRuntimeItemStatus status,
  }) {
    var next = eventSnapshot == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(eventSnapshot);

    if (rawMethod == 'item/commandExecution/terminalInteraction' &&
        existingSnapshot != null) {
      next = <String, dynamic>{...existingSnapshot, ...next};
    }

    _carryForward(next, existingSnapshot, key: 'command');
    _carryForward(next, existingSnapshot, key: 'processId');
    _carryForward(next, existingSnapshot, key: 'process_id');
    _carryForwardTerminalInput(next, existingSnapshot);

    final exitCode =
        exitCodeValue(eventSnapshot) ?? exitCodeValue(existingSnapshot);
    if (exitCode != null) {
      next['exitCode'] = exitCode;
    }

    final output =
        explicitOutputPayload(next) ?? explicitOutputPayload(existingSnapshot);
    if (output != null) {
      next[aggregatedOutputKey] = output.value;
      next.remove('aggregated_output');
      if (output.value.isEmpty) {
        next[retainedOutputStateKey] = retainedOutputStateEmpty;
      } else {
        next.remove(retainedOutputStateKey);
      }
    } else {
      final retainedState =
          explicitOutputState(next) ?? explicitOutputState(existingSnapshot);
      if (retainedState != null) {
        next[retainedOutputStateKey] = retainedState;
      }
    }

    if (status != TranscriptRuntimeItemStatus.inProgress &&
        explicitOutputPayload(next) == null &&
        explicitOutputState(next) == null) {
      next[retainedOutputStateKey] = retainedOutputStateUncaptured;
    }

    return next.isEmpty ? null : next;
  }

  static Map<String, dynamic>? mergeContentDeltaSnapshot(
    Map<String, dynamic>? existingSnapshot,
    String delta,
  ) {
    final next = existingSnapshot == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(existingSnapshot);
    final existingOutput = explicitOutputPayload(existingSnapshot);
    next[aggregatedOutputKey] = '${existingOutput?.value ?? ''}$delta';
    next.remove('aggregated_output');
    next.remove(retainedOutputStateKey);

    if (_isBackgroundTerminalWaitSnapshot(next)) {
      next.remove('stdin');
    }

    return next.isEmpty ? null : next;
  }

  static ({String value})? explicitOutputPayload(
    Map<String, dynamic>? snapshot,
  ) {
    if (snapshot == null) {
      return null;
    }

    if (_explicitString(snapshot, aggregatedOutputKey) case final output?) {
      return (value: output);
    }
    if (_explicitString(snapshot, 'aggregated_output') case final output?) {
      return (value: output);
    }

    final result = _object(snapshot['result']);
    if (_explicitString(result, 'output') case final output?) {
      return (value: output);
    }

    final topLevelStreams = _combinedStreamOutput(
      stdout: _explicitString(snapshot, 'stdout'),
      stderr: _explicitString(snapshot, 'stderr'),
      hasStdout: snapshot.containsKey('stdout'),
      hasStderr: snapshot.containsKey('stderr'),
    );
    if (topLevelStreams != null) {
      return (value: topLevelStreams);
    }

    final resultStreams = _combinedStreamOutput(
      stdout: _explicitString(result, 'stdout'),
      stderr: _explicitString(result, 'stderr'),
      hasStdout: result?.containsKey('stdout') ?? false,
      hasStderr: result?.containsKey('stderr') ?? false,
    );
    if (resultStreams != null) {
      return (value: resultStreams);
    }

    return null;
  }

  static String? explicitOutputState(Map<String, dynamic>? snapshot) {
    final value = snapshot?[retainedOutputStateKey];
    if (value is! String) {
      return null;
    }

    return switch (value.trim().toLowerCase()) {
      retainedOutputStateEmpty => retainedOutputStateEmpty,
      retainedOutputStateUncaptured => retainedOutputStateUncaptured,
      _ => null,
    };
  }

  static int? exitCodeValue(Map<String, dynamic>? snapshot) {
    final result = _object(snapshot?['result']);
    final raw =
        snapshot?['exitCode'] ??
        snapshot?['exit_code'] ??
        result?['exitCode'] ??
        result?['exit_code'];
    return raw is num ? raw.toInt() : null;
  }

  static void _carryForward(
    Map<String, dynamic> next,
    Map<String, dynamic>? existingSnapshot, {
    required String key,
  }) {
    if (next.containsKey(key) || existingSnapshot == null) {
      return;
    }
    if (!existingSnapshot.containsKey(key)) {
      return;
    }

    next[key] = existingSnapshot[key];
  }

  static void _carryForwardTerminalInput(
    Map<String, dynamic> next,
    Map<String, dynamic>? existingSnapshot,
  ) {
    if (next.containsKey('stdin') || existingSnapshot == null) {
      return;
    }

    final stdin = existingSnapshot['stdin'];
    if (stdin is String) {
      next['stdin'] = stdin;
    }
  }

  static String? _explicitString(Map<String, dynamic>? value, String key) {
    if (value == null || !value.containsKey(key)) {
      return null;
    }
    final raw = value[key];
    return raw is String ? raw : null;
  }

  static Map<String, dynamic>? _object(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static String? _combinedStreamOutput({
    required String? stdout,
    required String? stderr,
    required bool hasStdout,
    required bool hasStderr,
  }) {
    if (!hasStdout && !hasStderr) {
      return null;
    }
    if ((hasStdout && stdout == null) || (hasStderr && stderr == null)) {
      return null;
    }

    final stdoutValue = stdout ?? '';
    final stderrValue = stderr ?? '';
    if (stdoutValue.isEmpty) {
      return stderrValue;
    }
    if (stderrValue.isEmpty) {
      return stdoutValue;
    }

    return stdoutValue.endsWith('\n') || stderrValue.startsWith('\n')
        ? '$stdoutValue$stderrValue'
        : '$stdoutValue\n$stderrValue';
  }

  static bool _isBackgroundTerminalWaitSnapshot(Map<String, dynamic> snapshot) {
    final stdin = snapshot['stdin'];
    if (stdin is! String || stdin.isNotEmpty) {
      return false;
    }

    final processId = snapshot['processId'] ?? snapshot['process_id'];
    return processId is String && processId.isNotEmpty;
  }
}
