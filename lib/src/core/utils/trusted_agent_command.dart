import 'package:flutter/foundation.dart';

@immutable
class TrustedAgentCommand {
  const TrustedAgentCommand({
    required this.executable,
    this.arguments = const <String>[],
  });

  final String executable;
  final List<String> arguments;

  bool get usesPathLookup =>
      executable != '~' &&
      !executable.contains('/') &&
      !executable.contains(r'\');
}

TrustedAgentCommand parseTrustedAgentCommand(String rawCommand) {
  final normalized = rawCommand.trim();
  if (normalized.isEmpty) {
    throw const FormatException('Agent command is required.');
  }

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

  for (var index = 0; index < normalized.length; index++) {
    final char = normalized[index];

    if (char == '\n' || char == '\r') {
      throw const FormatException('Agent command must stay on one line.');
    }

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
        continue;
      }
      if (char == r'$' || char == '`') {
        throw const FormatException(_shellExpansionMessage);
      }
      if (char == '\\') {
        final next = index + 1 < normalized.length ? normalized[index + 1] : '';
        if (_canEscapeInsideDoubleQuotes(next)) {
          escaping = true;
          continue;
        }
      }
      buffer.write(char);
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
    if (_isWhitespace(char)) {
      flushBuffer();
      continue;
    }
    if (_isShellOperator(char)) {
      throw const FormatException(_shellOperatorMessage);
    }
    if (char == r'$' || char == '`') {
      throw const FormatException(_shellExpansionMessage);
    }
    if (char == '\\') {
      final next = index + 1 < normalized.length ? normalized[index + 1] : '';
      if (_canEscapeOutsideQuotes(next)) {
        escaping = true;
        continue;
      }
      buffer.write(char);
      continue;
    }

    buffer.write(char);
  }

  if (escaping || quote != null) {
    throw const FormatException(
      'Agent command has an unmatched quote or escape.',
    );
  }

  flushBuffer();
  if (tokens.isEmpty || tokens.first.trim().isEmpty) {
    throw const FormatException('Agent command must start with an executable.');
  }

  return TrustedAgentCommand(
    executable: tokens.first,
    arguments: List<String>.unmodifiable(tokens.skip(1)),
  );
}

const String _shellOperatorMessage =
    'Use an executable plus fixed arguments only. Shell operators like &&, |, ;, >, and < are not supported. Use a wrapper script if setup is required.';

const String _shellExpansionMessage =
    'Use an executable plus fixed arguments only. Shell expansion is not supported here. Use an explicit path or a wrapper script instead.';

bool _isWhitespace(String value) => RegExp(r'\s').hasMatch(value);

bool _isShellOperator(String value) =>
    value == ';' ||
    value == '&' ||
    value == '|' ||
    value == '>' ||
    value == '<';

bool _canEscapeInsideDoubleQuotes(String value) =>
    value == '"' || value == '\\' || value == r'$' || value == '`';

bool _canEscapeOutsideQuotes(String value) =>
    _isWhitespace(value) ||
    value == '"' ||
    value == "'" ||
    value == '\\' ||
    value == ';' ||
    value == '&' ||
    value == '|' ||
    value == '>' ||
    value == '<' ||
    value == r'$' ||
    value == '`';
