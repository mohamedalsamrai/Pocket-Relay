part of 'chat_session_controller.dart';

const _terminalItemSupport = TranscriptItemSupport();

Future<ChatWorkLogTerminalContract> _hydrateChatWorkLogTerminal(
  ChatSessionController controller,
  ChatWorkLogTerminalContract terminal,
) async {
  final itemId = terminal.itemId?.trim();
  final threadId = terminal.threadId?.trim();
  final turnId = _trimmedTerminalIdentifier(terminal.turnId);
  if ((itemId?.isEmpty ?? true) || (threadId?.isEmpty ?? true)) {
    return terminal;
  }

  final timelineActiveTurn = controller._sessionState
      .timelineForThread(threadId!)
      ?.activeTurn;
  final sessionActiveTurn = controller._sessionState.activeTurn;
  final activeTurn =
      timelineActiveTurn ??
      (sessionActiveTurn?.threadId == threadId ? sessionActiveTurn : null);
  final activeItem = _matchingActiveTerminalItem(
    activeTurn,
    itemId: itemId!,
    threadId: threadId,
    turnId: turnId,
  );
  if (activeItem != null) {
    return _terminalFromActiveItem(terminal, activeItem);
  }

  try {
    final thread = await controller.agentAdapterClient.readThreadWithTurns(
      threadId: threadId,
    );
    final historyItem = _findWorkLogHistoryItem(thread, itemId, turnId: turnId);
    if (historyItem == null) {
      return terminal;
    }
    return _terminalFromHistoryItem(terminal, historyItem);
  } catch (_) {
    return terminal;
  }
}

TranscriptSessionActiveItem? _matchingActiveTerminalItem(
  TranscriptActiveTurnState? activeTurn, {
  required String itemId,
  required String threadId,
  required String? turnId,
}) {
  if (activeTurn == null ||
      !_matchesTerminalTurnId(activeTurn.turnId, turnId)) {
    return null;
  }

  final activeItem = activeTurn.itemsById[itemId];
  if (activeItem == null ||
      activeItem.threadId != threadId ||
      activeItem.itemType != TranscriptCanonicalItemType.commandExecution ||
      !_matchesTerminalTurnId(activeItem.turnId, turnId)) {
    return null;
  }
  return activeItem;
}

ChatWorkLogTerminalContract _terminalFromActiveItem(
  ChatWorkLogTerminalContract terminal,
  TranscriptSessionActiveItem item,
) {
  final snapshot = item.snapshot;
  final terminalInput =
      _nonBlankTerminalStringPreservingWhitespace(snapshot?['stdin']) ??
      terminal.terminalInput;
  final terminalOutput =
      _terminalOutputFromSnapshot(snapshot) ??
      _activeTerminalOutput(item.body, terminalInput) ??
      terminal.terminalOutput;
  return terminal.copyWith(
    commandText: _terminalString(item.title) ?? terminal.commandText,
    isRunning: item.isRunning,
    isFailed: !item.isRunning && item.exitCode != null && item.exitCode != 0,
    exitCode: item.exitCode ?? terminal.exitCode,
    processId: _terminalProcessId(snapshot) ?? terminal.processId,
    terminalInput: terminalInput,
    terminalOutput: terminalOutput,
    activitySummary:
        _terminalActivitySummaryFromActiveItem(
          item,
          terminalInput: terminalInput,
          terminalOutput: terminalOutput,
        ) ??
        terminal.activitySummary,
  );
}

AgentAdapterHistoryItem? _findWorkLogHistoryItem(
  AgentAdapterThreadHistory thread,
  String itemId, {
  required String? turnId,
}) {
  for (final turn in thread.turns.reversed) {
    if (!_matchesTerminalTurnId(turn.id, turnId)) {
      continue;
    }
    for (final item in turn.items.reversed) {
      if (item.id == itemId) {
        return item;
      }
    }
  }
  return null;
}

ChatWorkLogTerminalContract _terminalFromHistoryItem(
  ChatWorkLogTerminalContract terminal,
  AgentAdapterHistoryItem item,
) {
  final raw = item.raw;
  final normalizedStatus = _terminalString(raw['status'])?.toLowerCase();
  final exitCode = _terminalExitCode(raw) ?? terminal.exitCode;
  final result = _terminalObject(raw['result']);
  final terminalOutput =
      _terminalOutputFromSnapshot(raw) ?? terminal.terminalOutput;
  return terminal.copyWith(
    commandText:
        _terminalString(raw['command'] ?? result?['command']) ??
        terminal.commandText,
    isRunning: switch (normalizedStatus) {
      'inprogress' || 'in_progress' || 'running' || 'active' => true,
      _ => false,
    },
    isFailed: _isTerminalFailureStatus(normalizedStatus),
    exitCode: exitCode,
    processId: _terminalProcessId(raw) ?? terminal.processId,
    terminalInput:
        _nonBlankTerminalStringPreservingWhitespace(raw['stdin']) ??
        terminal.terminalInput,
    terminalOutput: terminalOutput,
    activitySummary:
        _terminalActivitySummaryFromSnapshot(
          raw,
          terminalOutput: terminalOutput,
        ) ??
        terminal.activitySummary,
  );
}

String? _terminalProcessId(Map<String, dynamic>? value) {
  final result = _terminalObject(value?['result']);
  return _terminalString(
    value?['processId'] ??
        value?['process_id'] ??
        result?['processId'] ??
        result?['process_id'],
  );
}

int? _terminalExitCode(Map<String, dynamic> value) {
  final result = _terminalObject(value['result']);
  final raw =
      value['exitCode'] ??
      value['exit_code'] ??
      result?['exitCode'] ??
      result?['exit_code'];
  return raw is num ? raw.toInt() : null;
}

Map<String, dynamic>? _terminalObject(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

String? _terminalString(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _nonBlankTerminalStringPreservingWhitespace(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return value;
}

String? _terminalOutputFromSnapshot(Map<String, dynamic>? value) {
  final result = _terminalObject(value?['result']);
  final aggregatedOutput = _nonBlankTerminalStringPreservingWhitespace(
    value?['aggregatedOutput'] ??
        value?['aggregated_output'] ??
        result?['output'],
  );
  if (aggregatedOutput != null) {
    return aggregatedOutput;
  }

  return _combinedTerminalStreamOutput(
    stdout: value?['stdout'] ?? result?['stdout'],
    stderr: value?['stderr'] ?? result?['stderr'],
  );
}

String? _combinedTerminalStreamOutput({
  required Object? stdout,
  required Object? stderr,
}) {
  final stdoutText = _nonBlankTerminalStringPreservingWhitespace(stdout);
  final stderrText = _nonBlankTerminalStringPreservingWhitespace(stderr);
  if (stdoutText == null && stderrText == null) {
    return null;
  }
  if (stdoutText == null) {
    return stderrText;
  }
  if (stderrText == null) {
    return stdoutText;
  }

  return stdoutText.endsWith('\n') || stderrText.startsWith('\n')
      ? '$stdoutText$stderrText'
      : '$stdoutText\n$stderrText';
}

String? _terminalActivitySummaryFromSnapshot(
  Map<String, dynamic>? value, {
  String? terminalOutput,
}) {
  if (value == null || terminalOutput != null) {
    return null;
  }

  final extractedSummary = _nonBlankTerminalStringPreservingWhitespace(
    _terminalItemSupport.extractTextFromSnapshot(value),
  );
  if (extractedSummary != null) {
    return extractedSummary;
  }

  final result = _terminalObject(value['result']);
  return _nonBlankTerminalStringPreservingWhitespace(
    _terminalItemSupport.extractTextFromSnapshot(
          result == null
              ? null
              : <String, dynamic>{
                  'summary': result['summary'],
                  'content': result['content'],
                  'text': result['text'],
                  'review': result['message'],
                },
        ) ??
        result?['message'] ??
        value['message'],
  );
}

String? _terminalActivitySummaryFromActiveItem(
  TranscriptSessionActiveItem item, {
  required String? terminalInput,
  required String? terminalOutput,
}) {
  final snapshotSummary = _terminalActivitySummaryFromSnapshot(
    item.snapshot,
    terminalOutput: terminalOutput,
  );
  if (snapshotSummary != null) {
    return snapshotSummary;
  }
  if (terminalOutput != null) {
    return null;
  }

  final value = _nonBlankTerminalStringPreservingWhitespace(item.body);
  if (value == null) {
    return null;
  }

  final title = _terminalString(item.title);
  if ((title != null && value.trim() == title.trim()) ||
      value == terminalInput) {
    return null;
  }

  return value;
}

String? _trimmedTerminalIdentifier(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

bool _matchesTerminalTurnId(String candidateTurnId, String? requestedTurnId) {
  return requestedTurnId == null || requestedTurnId == candidateTurnId;
}

bool _isTerminalFailureStatus(String? status) {
  return switch (status) {
    'failed' ||
    'error' ||
    'errored' ||
    'declined' ||
    'cancelled' ||
    'canceled' ||
    'interrupted' ||
    'terminated' => true,
    _ => false,
  };
}

String? _activeTerminalOutput(String body, String? terminalInput) {
  final value = _nonBlankTerminalStringPreservingWhitespace(body);
  if (value == null) {
    return null;
  }
  if (terminalInput == null || !value.startsWith(terminalInput)) {
    return value;
  }

  final output = value.substring(terminalInput.length);
  return output.isEmpty ? null : output;
}
