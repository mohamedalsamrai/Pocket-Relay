part of 'chat_work_log_item_projector.dart';

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

    final pathResult = _tryResolveGetContentPathParameter(
      tokens: tokens,
      index: index,
      normalizedToken: normalizedToken,
    );
    if (pathResult != null) {
      if (path != null) {
        return null;
      }
      path = pathResult.value;
      index = pathResult.nextIndex;
      continue;
    }

    final lineModeResult = _tryResolveGetContentLineModeParameter(
      tokens: tokens,
      index: index,
      normalizedToken: normalizedToken,
    );
    if (lineModeResult != null) {
      mode = lineModeResult.mode;
      lineCount = lineModeResult.lineCount;
      index = lineModeResult.nextIndex;
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

_ResolvedPowerShellParameter? _tryResolveGetContentPathParameter({
  required List<String> tokens,
  required int index,
  required String normalizedToken,
}) {
  String? parameterName;
  if (_isPowerShellNamedParameter(normalizedToken, 'path')) {
    parameterName = 'path';
  } else if (_isPowerShellNamedParameter(normalizedToken, 'literalpath')) {
    parameterName = 'literalpath';
  }
  if (parameterName == null) {
    return null;
  }

  return _resolvePowerShellParameterValue(
    tokens: tokens,
    index: index,
    parameterName: parameterName,
  );
}

_ParsedGetContentLineModeParameter? _tryResolveGetContentLineModeParameter({
  required List<String> tokens,
  required int index,
  required String normalizedToken,
}) {
  String? parameterName;
  ChatGetContentReadMode? mode;
  if (_isPowerShellNamedParameter(normalizedToken, 'totalcount')) {
    parameterName = 'totalcount';
    mode = ChatGetContentReadMode.firstLines;
  } else if (_isPowerShellNamedParameter(normalizedToken, 'tail')) {
    parameterName = 'tail';
    mode = ChatGetContentReadMode.lastLines;
  }
  if (parameterName == null || mode == null) {
    return null;
  }

  final result = _resolvePowerShellParameterValue(
    tokens: tokens,
    index: index,
    parameterName: parameterName,
  );
  if (result == null) {
    return null;
  }

  final parsedCount = _parsePositiveInt(result.value);
  if (parsedCount == null) {
    return null;
  }

  return _ParsedGetContentLineModeParameter(
    mode: mode,
    lineCount: parsedCount,
    nextIndex: result.nextIndex,
  );
}

_ParsedSelectObjectReadProjection? _tryParseSelectObjectReadProjection(
  List<String> tokens,
) {
  if (tokens.length < 3 || _commandName(tokens.first) != 'select-object') {
    return null;
  }

  int? firstCount;
  int? lastCount;
  int? skipCount;

  var index = 1;
  while (index < tokens.length) {
    final token = tokens[index];
    final normalizedToken = token.toLowerCase();

    if (_isPowerShellNamedParameter(normalizedToken, 'first')) {
      final result = _resolvePowerShellParameterValue(
        tokens: tokens,
        index: index,
        parameterName: 'first',
      );
      if (result == null || firstCount != null || lastCount != null) {
        return null;
      }
      firstCount = _parsePositiveInt(result.value);
      if (firstCount == null) {
        return null;
      }
      index = result.nextIndex;
      continue;
    }

    if (_isPowerShellNamedParameter(normalizedToken, 'last')) {
      final result = _resolvePowerShellParameterValue(
        tokens: tokens,
        index: index,
        parameterName: 'last',
      );
      if (result == null || lastCount != null || firstCount != null) {
        return null;
      }
      lastCount = _parsePositiveInt(result.value);
      if (lastCount == null) {
        return null;
      }
      index = result.nextIndex;
      continue;
    }

    if (_isPowerShellNamedParameter(normalizedToken, 'skip')) {
      final result = _resolvePowerShellParameterValue(
        tokens: tokens,
        index: index,
        parameterName: 'skip',
      );
      if (result == null || skipCount != null) {
        return null;
      }
      skipCount = _parseNonNegativeInt(result.value);
      if (skipCount == null) {
        return null;
      }
      index = result.nextIndex;
      continue;
    }

    return null;
  }

  if (firstCount != null) {
    if (skipCount == null || skipCount == 0) {
      return _ParsedSelectObjectReadProjection(
        mode: ChatGetContentReadMode.firstLines,
        lineCount: firstCount,
      );
    }
    return _ParsedSelectObjectReadProjection(
      mode: ChatGetContentReadMode.lineRange,
      lineStart: skipCount + 1,
      lineEnd: skipCount + firstCount,
    );
  }

  if (lastCount != null && skipCount == null) {
    return _ParsedSelectObjectReadProjection(
      mode: ChatGetContentReadMode.lastLines,
      lineCount: lastCount,
    );
  }

  return null;
}

class _ParsedSelectObjectReadProjection {
  const _ParsedSelectObjectReadProjection({
    required this.mode,
    this.lineCount,
    this.lineStart,
    this.lineEnd,
  });

  final ChatGetContentReadMode mode;
  final int? lineCount;
  final int? lineStart;
  final int? lineEnd;
}

class _ParsedGetContentLineModeParameter {
  const _ParsedGetContentLineModeParameter({
    required this.mode,
    required this.lineCount,
    required this.nextIndex,
  });

  final ChatGetContentReadMode mode;
  final int lineCount;
  final int nextIndex;
}
