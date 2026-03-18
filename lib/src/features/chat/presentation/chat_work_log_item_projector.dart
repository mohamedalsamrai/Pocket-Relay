import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_work_log_contract.dart';

class ChatWorkLogItemProjector {
  const ChatWorkLogItemProjector();

  static final RegExp _sedPrintRangePattern = RegExp(r'^(\d+)(?:,(\d+))?p$');
  static final RegExp _shortHeadTailCountPattern = RegExp(r'^-(\d+)$');

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
        ? _tryParseReadCommand(normalizedTitle)
        : null;

    if (readCommand != null) {
      return _projectReadCommand(
        readCommand: readCommand,
        entry: entry,
        normalizedTitle: normalizedTitle,
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

  ChatFileReadWorkLogEntryContract _projectReadCommand({
    required _ParsedReadCommand readCommand,
    required CodexWorkLogEntry entry,
    required String normalizedTitle,
  }) {
    final fileName = _fileNameForPath(readCommand.path);
    return switch (readCommand) {
      final _ParsedSedReadCommand sedRead => ChatSedReadWorkLogEntryContract(
        id: entry.id,
        commandText: normalizedTitle,
        fileName: fileName,
        filePath: sedRead.path,
        lineStart: sedRead.lineStart,
        lineEnd: sedRead.lineEnd,
        turnId: entry.turnId,
        isRunning: entry.isRunning,
        exitCode: entry.exitCode,
      ),
      final _ParsedCatReadCommand catRead => ChatCatReadWorkLogEntryContract(
        id: entry.id,
        commandText: normalizedTitle,
        fileName: fileName,
        filePath: catRead.path,
        turnId: entry.turnId,
        isRunning: entry.isRunning,
        exitCode: entry.exitCode,
      ),
      final _ParsedHeadReadCommand headRead => ChatHeadReadWorkLogEntryContract(
        id: entry.id,
        commandText: normalizedTitle,
        fileName: fileName,
        filePath: headRead.path,
        lineCount: headRead.lineCount,
        turnId: entry.turnId,
        isRunning: entry.isRunning,
        exitCode: entry.exitCode,
      ),
      final _ParsedTailReadCommand tailRead => ChatTailReadWorkLogEntryContract(
        id: entry.id,
        commandText: normalizedTitle,
        fileName: fileName,
        filePath: tailRead.path,
        lineCount: tailRead.lineCount,
        turnId: entry.turnId,
        isRunning: entry.isRunning,
        exitCode: entry.exitCode,
      ),
      final _ParsedGetContentReadCommand getContentRead =>
        ChatGetContentReadWorkLogEntryContract(
          id: entry.id,
          commandText: normalizedTitle,
          fileName: fileName,
          filePath: getContentRead.path,
          mode: getContentRead.mode,
          lineCount: getContentRead.lineCount,
          turnId: entry.turnId,
          isRunning: entry.isRunning,
          exitCode: entry.exitCode,
        ),
    };
  }

  _ParsedReadCommand? _tryParseReadCommand(String commandText) {
    if (commandText.isEmpty || _containsShellOperators(commandText)) {
      return null;
    }

    return _tryParseReadCommandTokens(
      _tokenizeShellCommand(commandText),
      originalCommandText: commandText,
    );
  }

  _ParsedReadCommand? _tryParseReadCommandTokens(
    List<String>? tokens, {
    required String originalCommandText,
  }) {
    if (tokens == null || tokens.isEmpty) {
      return null;
    }

    final commandName = _commandName(tokens.first);
    if (commandName == 'pwsh' || commandName == 'powershell') {
      final unwrappedCommand = _unwrapPowerShellWrappedCommand(tokens);
      if (unwrappedCommand == null || unwrappedCommand == originalCommandText) {
        return null;
      }
      return _tryParseReadCommand(unwrappedCommand);
    }

    return switch (commandName) {
      'sed' => _tryParseSedReadCommand(tokens),
      'cat' => _tryParseCatReadCommand(tokens),
      'head' => _tryParseHeadReadCommand(tokens),
      'tail' => _tryParseTailReadCommand(tokens),
      'get-content' => _tryParseGetContentReadCommand(tokens),
      _ => null,
    };
  }

  _ParsedSedReadCommand? _tryParseSedReadCommand(List<String> tokens) {
    if (tokens.length < 4) {
      return null;
    }

    var index = 1;
    var hasPrintOnlyFlag = false;
    String? scriptToken;
    while (index < tokens.length) {
      final token = tokens[index];
      if (!token.startsWith('-') || token == '-') {
        break;
      }
      if (token == '--') {
        index++;
        break;
      }
      if (token == '-n') {
        hasPrintOnlyFlag = true;
        index++;
        continue;
      }
      if (token == '-e') {
        if (scriptToken != null || index + 1 >= tokens.length) {
          return null;
        }
        scriptToken = tokens[index + 1];
        index += 2;
        continue;
      }
      if (token == '-ne' || token == '-en') {
        if (scriptToken != null || index + 1 >= tokens.length) {
          return null;
        }
        hasPrintOnlyFlag = true;
        scriptToken = tokens[index + 1];
        index += 2;
        continue;
      }
      if (token != '-n') {
        return null;
      }
    }

    if (!hasPrintOnlyFlag || index >= tokens.length) {
      return null;
    }

    final resolvedScriptToken = scriptToken ?? tokens[index];
    final scriptMatch = _sedPrintRangePattern.firstMatch(resolvedScriptToken);
    if (scriptMatch == null) {
      return null;
    }
    if (scriptToken == null) {
      index++;
    }

    if (index < tokens.length && tokens[index] == '--') {
      index++;
    }

    if (index != tokens.length - 1) {
      return null;
    }

    final path = tokens[index].trim();
    if (!_isFileTarget(path)) {
      return null;
    }

    final lineStart = int.parse(scriptMatch.group(1)!);
    final lineEnd = int.parse(scriptMatch.group(2) ?? scriptMatch.group(1)!);
    if (lineStart <= 0 || lineEnd < lineStart) {
      return null;
    }
    return _ParsedSedReadCommand(
      lineStart: lineStart,
      lineEnd: lineEnd,
      path: path,
    );
  }

  _ParsedCatReadCommand? _tryParseCatReadCommand(List<String> tokens) {
    var index = 1;
    if (index < tokens.length && tokens[index] == '--') {
      index++;
    } else if (index < tokens.length && tokens[index].startsWith('-')) {
      return null;
    }

    if (index != tokens.length - 1) {
      return null;
    }

    final path = tokens[index].trim();
    if (!_isFileTarget(path)) {
      return null;
    }
    return _ParsedCatReadCommand(path: path);
  }

  _ParsedHeadReadCommand? _tryParseHeadReadCommand(List<String> tokens) {
    final parsed = _parseHeadTailCommand(tokens);
    return parsed == null
        ? null
        : _ParsedHeadReadCommand(
            path: parsed.path,
            lineCount: parsed.lineCount,
          );
  }

  _ParsedTailReadCommand? _tryParseTailReadCommand(List<String> tokens) {
    final parsed = _parseHeadTailCommand(tokens);
    return parsed == null
        ? null
        : _ParsedTailReadCommand(
            path: parsed.path,
            lineCount: parsed.lineCount,
          );
  }

  _ParsedHeadTailCommand? _parseHeadTailCommand(List<String> tokens) {
    if (tokens.length < 2) {
      return null;
    }

    var index = 1;
    var lineCount = 10;
    while (index < tokens.length) {
      final token = tokens[index];
      if (token == '--') {
        index++;
        break;
      }
      if (!token.startsWith('-') || token == '-') {
        break;
      }

      if (token == '-n' || token == '--lines') {
        if (index + 1 >= tokens.length) {
          return null;
        }
        final parsedCount = _parsePositiveInt(tokens[index + 1]);
        if (parsedCount == null) {
          return null;
        }
        lineCount = parsedCount;
        index += 2;
        continue;
      }

      if (token.startsWith('-n') && token.length > 2) {
        final parsedCount = _parsePositiveInt(token.substring(2));
        if (parsedCount == null) {
          return null;
        }
        lineCount = parsedCount;
        index++;
        continue;
      }

      if (token.startsWith('--lines=')) {
        final parsedCount = _parsePositiveInt(
          token.substring('--lines='.length),
        );
        if (parsedCount == null) {
          return null;
        }
        lineCount = parsedCount;
        index++;
        continue;
      }

      final shortCountMatch = _shortHeadTailCountPattern.firstMatch(token);
      if (shortCountMatch != null) {
        final parsedCount = _parsePositiveInt(shortCountMatch.group(1)!);
        if (parsedCount == null) {
          return null;
        }
        lineCount = parsedCount;
        index++;
        continue;
      }

      return null;
    }

    if (index != tokens.length - 1) {
      return null;
    }

    final path = tokens[index].trim();
    if (!_isFileTarget(path)) {
      return null;
    }

    return _ParsedHeadTailCommand(path: path, lineCount: lineCount);
  }

  _ParsedGetContentReadCommand? _tryParseGetContentReadCommand(
    List<String> tokens,
  ) {
    if (tokens.length < 2) {
      return null;
    }

    String? path;
    ChatGetContentReadMode mode = ChatGetContentReadMode.fullFile;
    int? lineCount;

    var index = 1;
    while (index < tokens.length) {
      final token = tokens[index];
      final normalizedToken = token.toLowerCase();

      if (_isPowerShellNamedParameter(normalizedToken, 'path')) {
        final result = _resolvePowerShellParameterValue(
          tokens: tokens,
          index: index,
          parameterName: 'path',
        );
        if (result == null || path != null) {
          return null;
        }
        path = result.value;
        index = result.nextIndex;
        continue;
      }

      if (_isPowerShellNamedParameter(normalizedToken, 'literalpath')) {
        final result = _resolvePowerShellParameterValue(
          tokens: tokens,
          index: index,
          parameterName: 'literalpath',
        );
        if (result == null || path != null) {
          return null;
        }
        path = result.value;
        index = result.nextIndex;
        continue;
      }

      if (_isPowerShellNamedParameter(normalizedToken, 'totalcount')) {
        final result = _resolvePowerShellParameterValue(
          tokens: tokens,
          index: index,
          parameterName: 'totalcount',
        );
        if (result == null) {
          return null;
        }
        final parsedCount = _parsePositiveInt(result.value);
        if (parsedCount == null) {
          return null;
        }
        mode = ChatGetContentReadMode.firstLines;
        lineCount = parsedCount;
        index = result.nextIndex;
        continue;
      }

      if (_isPowerShellNamedParameter(normalizedToken, 'tail')) {
        final result = _resolvePowerShellParameterValue(
          tokens: tokens,
          index: index,
          parameterName: 'tail',
        );
        if (result == null) {
          return null;
        }
        final parsedCount = _parsePositiveInt(result.value);
        if (parsedCount == null) {
          return null;
        }
        mode = ChatGetContentReadMode.lastLines;
        lineCount = parsedCount;
        index = result.nextIndex;
        continue;
      }

      if (normalizedToken == '-raw') {
        index++;
        continue;
      }

      if (token.startsWith('-')) {
        return null;
      }

      if (path != null) {
        return null;
      }
      path = token;
      index++;
    }

    if (!_isFileTarget(path)) {
      return null;
    }

    return _ParsedGetContentReadCommand(
      path: path!,
      mode: mode,
      lineCount: lineCount,
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
      final next = index + 1 < commandText.length
          ? commandText[index + 1]
          : null;
      if (next != null &&
          (RegExp(r'\s').hasMatch(next) ||
              next == '"' ||
              next == "'" ||
              next == '\\' ||
              next == ';' ||
              next == '&' ||
              next == '|' ||
              next == '>' ||
              next == '<' ||
              next == '`')) {
        escaping = true;
        continue;
      }
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

  for (var index = 0; index < commandText.length; index++) {
    final char = commandText[index];
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
        final next = index + 1 < commandText.length
            ? commandText[index + 1]
            : null;
        if (next != null &&
            (RegExp(r'\s').hasMatch(next) ||
                next == '"' ||
                next == "'" ||
                next == '\\')) {
          escaping = true;
          continue;
        }
        buffer.write(char);
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
      final next = index + 1 < commandText.length
          ? commandText[index + 1]
          : null;
      if (next != null &&
          (RegExp(r'\s').hasMatch(next) ||
              next == '"' ||
              next == "'" ||
              next == '\\')) {
        escaping = true;
        continue;
      }
      buffer.write(char);
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

String _commandName(String executableToken) {
  final normalizedToken = executableToken.replaceAll('\\', '/');
  final segments = normalizedToken
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  final fileName = segments.isEmpty ? executableToken : segments.last;
  return fileName.toLowerCase().replaceFirst(RegExp(r'\.exe$'), '');
}

String? _unwrapPowerShellWrappedCommand(List<String> tokens) {
  for (var index = 1; index < tokens.length; index++) {
    final token = tokens[index].toLowerCase();
    if (token == '-command' || token == '-c') {
      final commandTokens = tokens.sublist(index + 1);
      if (commandTokens.isEmpty) {
        return null;
      }
      return commandTokens.join(' ').trim();
    }
  }
  return null;
}

bool _isFileTarget(String? path) {
  final value = path?.trim();
  return value != null && value.isNotEmpty && value != '-';
}

int? _parsePositiveInt(String value) {
  final parsed = int.tryParse(value.trim());
  if (parsed == null || parsed <= 0) {
    return null;
  }
  return parsed;
}

bool _isPowerShellNamedParameter(String token, String parameterName) {
  return token == '-$parameterName' || token.startsWith('-$parameterName:');
}

_ResolvedPowerShellParameter? _resolvePowerShellParameterValue({
  required List<String> tokens,
  required int index,
  required String parameterName,
}) {
  final token = tokens[index];
  final prefix = '-$parameterName:';
  if (token.toLowerCase().startsWith(prefix)) {
    final value = token.substring(prefix.length);
    if (value.isEmpty) {
      return null;
    }
    return _ResolvedPowerShellParameter(value: value, nextIndex: index + 1);
  }
  if (index + 1 >= tokens.length) {
    return null;
  }
  return _ResolvedPowerShellParameter(
    value: tokens[index + 1],
    nextIndex: index + 2,
  );
}

sealed class _ParsedReadCommand {
  const _ParsedReadCommand({required this.path});

  final String path;
}

class _ParsedSedReadCommand extends _ParsedReadCommand {
  const _ParsedSedReadCommand({
    required this.lineStart,
    required this.lineEnd,
    required super.path,
  });

  final int lineStart;
  final int lineEnd;
}

class _ParsedCatReadCommand extends _ParsedReadCommand {
  const _ParsedCatReadCommand({required super.path});
}

class _ParsedHeadReadCommand extends _ParsedReadCommand {
  const _ParsedHeadReadCommand({required super.path, required this.lineCount});

  final int lineCount;
}

class _ParsedTailReadCommand extends _ParsedReadCommand {
  const _ParsedTailReadCommand({required super.path, required this.lineCount});

  final int lineCount;
}

class _ParsedHeadTailCommand {
  const _ParsedHeadTailCommand({required this.path, required this.lineCount});

  final String path;
  final int lineCount;
}

class _ParsedGetContentReadCommand extends _ParsedReadCommand {
  const _ParsedGetContentReadCommand({
    required super.path,
    required this.mode,
    required this.lineCount,
  });

  final ChatGetContentReadMode mode;
  final int? lineCount;
}

class _ResolvedPowerShellParameter {
  const _ResolvedPowerShellParameter({
    required this.value,
    required this.nextIndex,
  });

  final String value;
  final int nextIndex;
}
