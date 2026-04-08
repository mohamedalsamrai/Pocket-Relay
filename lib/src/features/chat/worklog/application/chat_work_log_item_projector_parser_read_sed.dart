part of 'chat_work_log_item_projector.dart';

_ParsedSedPrintRangeCommand? _parseSedPrintRangeCommand(
  List<String> tokens, {
  required bool requiresFileTarget,
}) {
  if (tokens.length < (requiresFileTarget ? 4 : 3) ||
      _commandName(tokens.first) != 'sed') {
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
    return null;
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

  String? path;
  if (requiresFileTarget) {
    if (index != tokens.length - 1) {
      return null;
    }
    path = tokens[index].trim();
    if (!_isFileTarget(path)) {
      return null;
    }
  } else if (index != tokens.length) {
    return null;
  }

  final lineStart = int.parse(scriptMatch.group(1)!);
  final lineEnd = int.parse(scriptMatch.group(2) ?? scriptMatch.group(1)!);
  if (lineStart <= 0 || lineEnd < lineStart) {
    return null;
  }

  return _ParsedSedPrintRangeCommand(
    lineStart: lineStart,
    lineEnd: lineEnd,
    path: path,
  );
}

String? _tryParseNlReadPath(List<String> tokens) {
  if (tokens.length < 2 || _commandName(tokens.first) != 'nl') {
    return null;
  }

  var index = 1;
  while (index < tokens.length) {
    final token = tokens[index];
    final normalizedToken = token.toLowerCase();
    if (token == '--') {
      index++;
      break;
    }
    if (!token.startsWith('-') || token == '-') {
      break;
    }
    if (normalizedToken == '-ba' || normalizedToken == '--body-numbering=a') {
      index++;
      continue;
    }
    if (normalizedToken == '-b' || normalizedToken == '--body-numbering') {
      if (index + 1 >= tokens.length ||
          tokens[index + 1].toLowerCase() != 'a') {
        return null;
      }
      index += 2;
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
  return path;
}

class _ParsedSedPrintRangeCommand {
  const _ParsedSedPrintRangeCommand({
    required this.lineStart,
    required this.lineEnd,
    this.path,
  });

  final int lineStart;
  final int lineEnd;
  final String? path;
}
