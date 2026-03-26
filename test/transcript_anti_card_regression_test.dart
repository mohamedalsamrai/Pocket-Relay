import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final List<RegExp> _forbiddenPathPatterns = <RegExp>[
  RegExp(r'(^|[/\\])cards([/\\]|$)'),
  RegExp(r'_card\.dart$'),
];

final List<MapEntry<RegExp, String>> _forbiddenContentChecks =
    <MapEntry<RegExp, String>>[
      MapEntry(
        RegExp(r'\b[A-Za-z_][A-Za-z0-9_]*Card\b'),
        'contains a *Card symbol',
      ),
      MapEntry(
        RegExp(r'\b[a-z0-9_]*_card[a-z0-9_]*\b'),
        'contains a _card identifier',
      ),
      MapEntry(
        RegExp(r'\bTranscriptBlocker\b'),
        'still references TranscriptBlocker',
      ),
    ];

void main() {
  test('transcript and worklog ownership seams stay free of card terminology', () {
    const auditRoots = <String>[
      'lib/src/features/chat/transcript/presentation/widgets/transcript',
      'lib/src/features/chat/worklog/presentation/widgets',
      'lib/src/features/chat/lane/presentation/widgets/chat_empty_state_body.dart',
      'lib/src/features/chat/lane/presentation/widgets/chat_empty_state_body_desktop.dart',
      'lib/src/features/chat/lane/presentation/widgets/chat_empty_state_body_mobile.dart',
      'lib/src/features/chat/lane/presentation/widgets/chat_empty_state_body_support.dart',
      'lib/src/core/ui/primitives/pocket_meta_surface.dart',
      'lib/widgetbook/story_catalog.dart',
      'lib/src/features/workspace/presentation/workspace_saved_connections_content.dart',
      'lib/src/features/workspace/presentation/workspace_saved_connections_content_items.dart',
      'lib/src/features/workspace/presentation/workspace_saved_connections_content_shell.dart',
    ];

    final violations = <String>[
      for (final path in auditRoots) ..._auditRoot(path),
    ];

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

List<String> _auditRoot(String rootPath) {
  final entityType = FileSystemEntity.typeSync(rootPath);
  if (entityType == FileSystemEntityType.notFound) {
    return <String>['missing audit root: $rootPath'];
  }

  final files = switch (entityType) {
    FileSystemEntityType.file => <File>[File(rootPath)],
    FileSystemEntityType.directory =>
      Directory(rootPath)
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList(growable: false),
    _ => const <File>[],
  };

  return <String>[for (final file in files) ..._auditFile(file)];
}

List<String> _auditFile(File file) {
  final relativePath = _relativePath(file.path);
  final contents = file.readAsStringSync();
  final violations = <String>[];

  for (final pattern in _forbiddenPathPatterns) {
    if (pattern.hasMatch(relativePath)) {
      violations.add('$relativePath uses forbidden card-oriented path naming');
    }
  }

  for (final check in _forbiddenContentChecks) {
    if (check.key.hasMatch(contents)) {
      violations.add('$relativePath ${check.value}');
    }
  }

  return violations;
}

String _relativePath(String path) {
  final root = Directory.current.path;
  final prefix = '$root${Platform.pathSeparator}';
  if (path.startsWith(prefix)) {
    return path.substring(prefix.length);
  }
  return path;
}
