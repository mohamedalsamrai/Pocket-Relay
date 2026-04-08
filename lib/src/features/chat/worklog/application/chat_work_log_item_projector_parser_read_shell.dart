part of 'chat_work_log_item_projector.dart';

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

_ParsedTypeReadCommand? _tryParseTypeReadCommand(List<String> tokens) {
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
  return _ParsedTypeReadCommand(path: path);
}

_ParsedMoreReadCommand? _tryParseMoreReadCommand(List<String> tokens) {
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
  return _ParsedMoreReadCommand(path: path);
}

_ParsedHeadReadCommand? _tryParseHeadReadCommand(List<String> tokens) {
  final parsed = _parseHeadTailCommand(tokens);
  return parsed == null
      ? null
      : _ParsedHeadReadCommand(path: parsed.path, lineCount: parsed.lineCount);
}

_ParsedTailReadCommand? _tryParseTailReadCommand(List<String> tokens) {
  final parsed = _parseHeadTailCommand(tokens);
  return parsed == null
      ? null
      : _ParsedTailReadCommand(path: parsed.path, lineCount: parsed.lineCount);
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
      final parsedCount = _parsePositiveInt(token.substring('--lines='.length));
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

_ParsedAwkReadCommand? _tryParseAwkReadCommand(List<String> tokens) {
  if (tokens.length != 3) {
    return null;
  }

  final script = tokens[1].trim();
  final path = tokens[2].trim();
  if (script.isEmpty || !_isFileTarget(path)) {
    return null;
  }

  final singleLineMatch = _awkSingleLineReadPattern.firstMatch(script);
  if (singleLineMatch != null) {
    final lineNumber = int.parse(singleLineMatch.group(1)!);
    if (lineNumber <= 0) {
      return null;
    }
    return _ParsedAwkReadCommand(
      path: path,
      lineStart: lineNumber,
      lineEnd: lineNumber,
    );
  }

  final rangeMatch = _awkRangeReadPattern.firstMatch(script);
  if (rangeMatch == null) {
    return null;
  }

  final lineStart = int.parse(rangeMatch.group(1)!);
  final lineEnd = int.parse(rangeMatch.group(2)!);
  if (lineStart <= 0 || lineEnd < lineStart) {
    return null;
  }

  return _ParsedAwkReadCommand(
    path: path,
    lineStart: lineStart,
    lineEnd: lineEnd,
  );
}
