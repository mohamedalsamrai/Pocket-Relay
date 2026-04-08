part of 'chat_work_log_item_projector.dart';

_ParsedSedReadCommand? _tryParseSedReadCommand(List<String> tokens) {
  final parsed = _parseSedPrintRangeCommand(tokens, requiresFileTarget: true);
  if (parsed == null || parsed.path == null) {
    return null;
  }

  return _ParsedSedReadCommand(
    lineStart: parsed.lineStart,
    lineEnd: parsed.lineEnd,
    path: parsed.path!,
  );
}

_ParsedSedReadCommand? _tryParseNumberedSedReadCommand(String commandText) {
  final pipeCommand = _splitSinglePipeCommand(commandText);
  if (pipeCommand == null) {
    return null;
  }

  final numberedInputTokens = _tokenizeShellCommand(pipeCommand.leftCommand);
  final rangedReadTokens = _tokenizeShellCommand(pipeCommand.rightCommand);
  if (numberedInputTokens == null || rangedReadTokens == null) {
    return null;
  }

  final path = _tryParseNlReadPath(numberedInputTokens);
  if (path == null) {
    return null;
  }

  final parsedSed = _parseSedPrintRangeCommand(
    rangedReadTokens,
    requiresFileTarget: false,
  );
  if (parsedSed == null) {
    return null;
  }

  return _ParsedSedReadCommand(
    lineStart: parsedSed.lineStart,
    lineEnd: parsedSed.lineEnd,
    path: path,
  );
}

_ParsedGetContentReadCommand? _tryParseSelectObjectReadCommand(
  String commandText,
) {
  final pipeCommand = _splitSinglePipeCommand(commandText);
  if (pipeCommand == null) {
    return null;
  }

  final sourceTokens = _tokenizeShellCommand(pipeCommand.leftCommand);
  final selectTokens = _tokenizeShellCommand(pipeCommand.rightCommand);
  if (sourceTokens == null || selectTokens == null) {
    return null;
  }

  final sourceRead = _tryParseGetContentReadCommand(sourceTokens);
  if (sourceRead == null ||
      sourceRead.mode != ChatGetContentReadMode.fullFile) {
    return null;
  }

  final projection = _tryParseSelectObjectReadProjection(selectTokens);
  if (projection == null) {
    return null;
  }

  return _ParsedGetContentReadCommand(
    path: sourceRead.path,
    mode: projection.mode,
    lineCount: projection.lineCount,
    lineStart: projection.lineStart,
    lineEnd: projection.lineEnd,
  );
}
