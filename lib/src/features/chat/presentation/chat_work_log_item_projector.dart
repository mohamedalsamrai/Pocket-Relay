import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_work_log_contract.dart';

class ChatWorkLogItemProjector {
  const ChatWorkLogItemProjector();

  static final RegExp _sedPrintRangePattern = RegExp(r'^(\d+)(?:,(\d+))?p$');

  ChatWorkLogGroupItemContract project(CodexWorkLogGroupBlock block) {
    return ChatWorkLogGroupItemContract(
      id: block.id,
      entries: block.entries.map(_projectEntry).toList(growable: false),
    );
  }

  ChatWorkLogEntryContract _projectEntry(CodexWorkLogEntry entry) {
    final normalizedTitle = _normalizeCompactToolLabel(entry.title);
    final readCommand =
        entry.entryKind == CodexWorkLogEntryKind.commandExecution
        ? _tryParseSedReadCommand(normalizedTitle)
        : null;

    if (readCommand != null) {
      return ChatReadCommandWorkLogEntryContract(
        id: entry.id,
        commandText: normalizedTitle,
        fileName: _fileNameForPath(readCommand.path),
        filePath: readCommand.path,
        lineStart: readCommand.lineStart,
        lineEnd: readCommand.lineEnd,
        turnId: entry.turnId,
        isRunning: entry.isRunning,
        exitCode: entry.exitCode,
      );
    }

    return ChatGenericWorkLogEntryContract(
      id: entry.id,
      entryKind: entry.entryKind,
      title: normalizedTitle,
      preview: _normalizedWorkLogPreview(entry.preview, normalizedTitle),
      turnId: entry.turnId,
      isRunning: entry.isRunning,
      exitCode: entry.exitCode,
    );
  }

  _ParsedSedReadCommand? _tryParseSedReadCommand(String commandText) {
    if (commandText.isEmpty || _containsShellOperators(commandText)) {
      return null;
    }

    final tokens = _tokenizeShellCommand(commandText);
    if (tokens == null || tokens.length < 4 || tokens.first != 'sed') {
      return null;
    }

    var index = 1;
    var hasPrintOnlyFlag = false;
    while (index < tokens.length) {
      final token = tokens[index];
      if (!token.startsWith('-') || token == '-') {
        break;
      }
      if (token == '--') {
        index++;
        break;
      }
      if (token != '-n') {
        return null;
      }
      hasPrintOnlyFlag = true;
      index++;
    }

    if (!hasPrintOnlyFlag || index >= tokens.length) {
      return null;
    }

    final scriptToken = tokens[index];
    final scriptMatch = _sedPrintRangePattern.firstMatch(scriptToken);
    if (scriptMatch == null) {
      return null;
    }
    index++;

    if (index < tokens.length && tokens[index] == '--') {
      index++;
    }

    if (index != tokens.length - 1) {
      return null;
    }

    final path = tokens[index].trim();
    if (path.isEmpty) {
      return null;
    }

    final lineStart = int.parse(scriptMatch.group(1)!);
    final lineEnd = int.parse(scriptMatch.group(2) ?? scriptMatch.group(1)!);
    return _ParsedSedReadCommand(
      lineStart: lineStart,
      lineEnd: lineEnd,
      path: path,
    );
  }
}

String _normalizeCompactToolLabel(String value) {
  return value
      .replaceFirst(
        RegExp(r'\s+(?:complete|completed)\s*$', caseSensitive: false),
        '',
      )
      .trim();
}

String? _normalizedWorkLogPreview(String? preview, String normalizedTitle) {
  final value = preview?.trim();
  if (value == null || value.isEmpty || value == normalizedTitle) {
    return null;
  }
  return value;
}

bool _containsShellOperators(String commandText) {
  var inSingleQuote = false;
  var inDoubleQuote = false;
  var escaping = false;

  for (var index = 0; index < commandText.length; index++) {
    final char = commandText[index];

    if (escaping) {
      escaping = false;
      continue;
    }
    if (inSingleQuote) {
      if (char == "'") {
        inSingleQuote = false;
      }
      continue;
    }
    if (inDoubleQuote) {
      if (char == '\\') {
        escaping = true;
        continue;
      }
      if (char == '"') {
        inDoubleQuote = false;
      }
      continue;
    }

    if (char == "'") {
      inSingleQuote = true;
      continue;
    }
    if (char == '"') {
      inDoubleQuote = true;
      continue;
    }
    if (char == '\\') {
      escaping = true;
      continue;
    }
    if (char == '\n' ||
        char == ';' ||
        char == '&' ||
        char == '|' ||
        char == '>' ||
        char == '<' ||
        char == '`') {
      return true;
    }
  }

  return false;
}

List<String>? _tokenizeShellCommand(String commandText) {
  final tokens = <String>[];
  final buffer = StringBuffer();
  String? quote;
  var escaping = false;

  void flushBuffer() {
    if (buffer.isEmpty) {
      return;
    }
    tokens.add(buffer.toString());
    buffer.clear();
  }

  for (final char in commandText.split('')) {
    if (escaping) {
      buffer.write(char);
      escaping = false;
      continue;
    }

    if (quote == "'") {
      if (char == "'") {
        quote = null;
      } else {
        buffer.write(char);
      }
      continue;
    }

    if (quote == '"') {
      if (char == '"') {
        quote = null;
      } else if (char == '\\') {
        escaping = true;
      } else {
        buffer.write(char);
      }
      continue;
    }

    if (char == "'") {
      quote = "'";
      continue;
    }
    if (char == '"') {
      quote = '"';
      continue;
    }
    if (char == '\\') {
      escaping = true;
      continue;
    }
    if (RegExp(r'\s').hasMatch(char)) {
      flushBuffer();
      continue;
    }

    buffer.write(char);
  }

  if (escaping || quote != null) {
    return null;
  }

  flushBuffer();
  return tokens.isEmpty ? null : tokens;
}

String _fileNameForPath(String path) {
  final normalizedPath = path.replaceAll('\\', '/');
  final segments = normalizedPath
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  return segments.isEmpty ? path : segments.last;
}

class _ParsedSedReadCommand {
  const _ParsedSedReadCommand({
    required this.lineStart,
    required this.lineEnd,
    required this.path,
  });

  final int lineStart;
  final int lineEnd;
  final String path;
}
