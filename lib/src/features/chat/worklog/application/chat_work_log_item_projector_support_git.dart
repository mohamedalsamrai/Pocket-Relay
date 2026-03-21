part of 'chat_work_log_item_projector.dart';

String? _gitScopeLabel(_ParsedGitInvocation invocation) {
  if (_isNonEmptyToken(invocation.repoPath)) {
    return 'In ${invocation.repoPath}';
  }
  if (_isNonEmptyToken(invocation.workTree)) {
    return 'Work tree ${invocation.workTree}';
  }
  if (_isNonEmptyToken(invocation.gitDir)) {
    return 'Git dir ${invocation.gitDir}';
  }
  return null;
}

List<String> _collectGitPositionalArgs(
  List<String> args, {
  Set<String> valueOptions = const <String>{},
  Set<String> shortValueOptions = const <String>{},
}) {
  final positionals = <String>[];
  var index = 0;
  var afterSeparator = false;

  while (index < args.length) {
    final token = args[index];
    final normalizedToken = token.toLowerCase();

    if (afterSeparator) {
      if (_isNonEmptyToken(token)) {
        positionals.add(token);
      }
      index++;
      continue;
    }

    if (token == '--') {
      afterSeparator = true;
      index++;
      continue;
    }

    if (!token.startsWith('-') || token == '-') {
      positionals.add(token);
      index++;
      continue;
    }

    if (valueOptions.contains(normalizedToken)) {
      if (index + 1 >= args.length) {
        return positionals;
      }
      index += 2;
      continue;
    }

    if (_matchesInlineLongOption(token, options: valueOptions)) {
      index++;
      continue;
    }

    if (_matchesCompactShortOption(token, options: shortValueOptions)) {
      index++;
      continue;
    }

    if (shortValueOptions.contains(token.substring(1))) {
      if (index + 1 >= args.length) {
        return positionals;
      }
      index += 2;
      continue;
    }

    index++;
  }

  return positionals;
}

String? _extractGitOptionValue(
  List<String> args, {
  Set<String> options = const <String>{},
  Set<String> shortOptions = const <String>{},
}) {
  for (var index = 0; index < args.length; index++) {
    final token = args[index];
    final normalizedToken = token.toLowerCase();
    if (options.contains(normalizedToken)) {
      if (index + 1 >= args.length) {
        return null;
      }
      return args[index + 1];
    }
    for (final option in options) {
      if (token.startsWith('$option=')) {
        return token.substring(option.length + 1);
      }
    }
    if (token.startsWith('-') &&
        !token.startsWith('--') &&
        token.length >= 2 &&
        shortOptions.contains(token[1])) {
      if (token.length > 2) {
        return token.substring(2);
      }
      if (index + 1 >= args.length) {
        return null;
      }
      return args[index + 1];
    }
  }
  return null;
}

bool _matchesInlineLongOption(String token, {required Set<String> options}) {
  if (!token.startsWith('--')) {
    return false;
  }
  for (final option in options.where((option) => option.startsWith('--'))) {
    if (token.startsWith('$option=')) {
      return true;
    }
  }
  return false;
}

bool _matchesCompactShortOption(String token, {required Set<String> options}) {
  if (!token.startsWith('-') || token.startsWith('--') || token.length <= 2) {
    return false;
  }
  return options.contains(token[1]);
}
