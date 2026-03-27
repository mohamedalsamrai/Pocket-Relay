part of 'chat_session_controller.dart';

Future<ChatWorkLogTerminalContract> _hydrateChatWorkLogTerminal(
  ChatSessionController controller,
  ChatWorkLogTerminalContract terminal,
) async {
  final itemId = terminal.itemId?.trim();
  final threadId = terminal.threadId?.trim();
  if (itemId == null ||
      itemId.isEmpty ||
      threadId == null ||
      threadId.isEmpty) {
    return terminal;
  }

  final activeTurn =
      controller._sessionState.timelineForThread(threadId)?.activeTurn ??
      (controller._sessionState.activeTurn?.threadId == threadId
          ? controller._sessionState.activeTurn
          : null);
  final activeItem = activeTurn?.itemsById[itemId];
  if (activeItem != null &&
      activeItem.threadId == threadId &&
      activeItem.itemType == CodexCanonicalItemType.commandExecution) {
    return _terminalFromActiveItem(terminal, activeItem);
  }

  try {
    final thread = await controller.appServerClient.readThreadWithTurns(
      threadId: threadId,
    );
    final historyItem = _findWorkLogHistoryItem(thread, itemId);
    if (historyItem == null) {
      return terminal;
    }
    return _terminalFromHistoryItem(terminal, historyItem);
  } catch (_) {
    return terminal;
  }
}

ChatWorkLogTerminalContract _terminalFromActiveItem(
  ChatWorkLogTerminalContract terminal,
  CodexSessionActiveItem item,
) {
  final snapshot = item.snapshot;
  final terminalInput =
      _terminalStringPreservingWhitespace(snapshot?['stdin']) ??
      terminal.terminalInput;
  return terminal.copyWith(
    commandText: _terminalString(item.title) ?? terminal.commandText,
    isRunning: item.isRunning,
    exitCode: item.exitCode ?? terminal.exitCode,
    processId: _terminalProcessId(snapshot) ?? terminal.processId,
    terminalInput: terminalInput,
    terminalOutput:
        _activeTerminalOutput(item.body, terminalInput) ??
        terminal.terminalOutput,
  );
}

CodexAppServerHistoryItem? _findWorkLogHistoryItem(
  CodexAppServerThreadHistory thread,
  String itemId,
) {
  for (final turn in thread.turns.reversed) {
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
  CodexAppServerHistoryItem item,
) {
  final raw = item.raw;
  final normalizedStatus = _terminalString(raw['status'])?.toLowerCase();
  final exitCode = _terminalExitCode(raw) ?? terminal.exitCode;
  return terminal.copyWith(
    commandText: _terminalString(raw['command']) ?? terminal.commandText,
    isRunning: switch (normalizedStatus) {
      'inprogress' || 'in_progress' || 'running' || 'active' => true,
      _ => false,
    },
    exitCode: exitCode,
    processId: _terminalProcessId(raw) ?? terminal.processId,
    terminalInput:
        _terminalStringPreservingWhitespace(raw['stdin']) ??
        terminal.terminalInput,
    terminalOutput:
        _terminalStringPreservingWhitespace(
          raw['aggregatedOutput'] ?? raw['aggregated_output'],
        ) ??
        terminal.terminalOutput,
  );
}

String? _terminalProcessId(Map<String, dynamic>? value) {
  return _terminalString(value?['processId'] ?? value?['process_id']);
}

int? _terminalExitCode(Map<String, dynamic> value) {
  final raw = value['exitCode'] ?? value['exit_code'];
  return raw is num ? raw.toInt() : null;
}

String? _terminalString(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _terminalStringPreservingWhitespace(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return value;
}

String? _activeTerminalOutput(String body, String? terminalInput) {
  final value = _terminalStringPreservingWhitespace(body);
  if (value == null) {
    return null;
  }
  if (terminalInput == null || !value.startsWith(terminalInput)) {
    return value;
  }

  final output = value.substring(terminalInput.length);
  return output.isEmpty ? null : output;
}
