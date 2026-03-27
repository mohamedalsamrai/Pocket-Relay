import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_changed_files_parser.dart';

void main() {
  const parser = TranscriptChangedFilesParser();

  test('extracts changed files and line counts from unified diff text', () {
    final files = parser.changedFilesFromSources(
      body:
          'diff --git a/lib/main.dart b/lib/main.dart\n'
          '--- a/lib/main.dart\n'
          '+++ b/lib/main.dart\n'
          '@@ -1,2 +1,3 @@\n'
          '-old line\n'
          '+new line\n'
          '+second line\n',
    );

    expect(files, hasLength(1));
    expect(files.single.path, 'lib/main.dart');
    expect(files.single.additions, 2);
    expect(files.single.deletions, 1);
  });

  test('merges nested payload paths with diff-derived file stats', () {
    final files = parser.changedFilesFromSources(
      body:
          'diff --git a/lib/app.dart b/lib/app.dart\n'
          '--- a/lib/app.dart\n'
          '+++ b/lib/app.dart\n'
          '@@ -1 +1 @@\n'
          '-old\n'
          '+new\n',
      rawPayload: <String, Object?>{
        'result': <String, Object?>{
          'files': <Object?>[
            <String, Object?>{'path': 'lib/app.dart'},
            <String, Object?>{'relativePath': 'README.md'},
          ],
        },
      },
    );

    expect(files.map((file) => file.path), ['README.md', 'lib/app.dart']);
    expect(files.last.additions, 1);
    expect(files.last.deletions, 1);
  });

  test('only returns real unified diffs from candidate fields', () {
    expect(
      parser.unifiedDiffFromSources(
        snapshot: const <String, Object?>{'text': 'plain text output'},
      ),
      isNull,
    );

    expect(
      parser.unifiedDiffFromSources(
        snapshot: const <String, Object?>{
          'text': 'plain tool output',
          'patch':
              'diff --git a/lib/app.dart b/lib/app.dart\n'
              '--- a/lib/app.dart\n'
              '+++ b/lib/app.dart\n'
              '@@ -1 +1 @@\n'
              '-old\n'
              '+new\n',
        },
      ),
      contains('diff --git'),
    );
  });

  test(
    'falls back to structured changes when body contains plain tool output',
    () {
      final unifiedDiff = parser.unifiedDiffFromSources(
        body: 'apply_patch exited successfully',
        snapshot: const <String, Object?>{
          'changes': <Object?>[
            <String, Object?>{
              'path': 'README.md',
              'kind': <String, Object?>{'type': 'add'},
              'diff': 'first line\nsecond line\n',
            },
          ],
        },
      );

      expect(unifiedDiff, contains('diff --git a/README.md b/README.md'));
      expect(unifiedDiff, contains('+first line'));
      expect(unifiedDiff, contains('+second line'));
    },
  );

  test(
    'builds grouped file stats and synthetic patches from structured changes',
    () {
      final files = parser.changedFilesFromSources(
        snapshot: const <String, Object?>{
          'changes': <Object?>[
            <String, Object?>{
              'path': 'README.md',
              'kind': <String, Object?>{'type': 'add'},
              'diff': 'first line\nsecond line\n',
            },
            <String, Object?>{
              'path': 'lib/app.dart',
              'kind': <String, Object?>{'type': 'update', 'move_path': null},
              'diff':
                  '--- a/lib/app.dart\n'
                  '+++ b/lib/app.dart\n'
                  '@@ -1 +1,2 @@\n'
                  '-old\n'
                  '+new\n'
                  '+second\n',
            },
          ],
        },
      );

      expect(files, hasLength(2));
      expect(files.first.path, 'README.md');
      expect(files.first.additions, 2);
      expect(files.first.deletions, 0);
      expect(files.last.path, 'lib/app.dart');
      expect(files.last.additions, 2);
      expect(files.last.deletions, 1);

      final unifiedDiff = parser.unifiedDiffFromSources(
        snapshot: const <String, Object?>{
          'changes': <Object?>[
            <String, Object?>{
              'path': 'README.md',
              'kind': <String, Object?>{'type': 'add'},
              'diff': 'first line\nsecond line\n',
            },
            <String, Object?>{
              'path': 'lib/app.dart',
              'kind': <String, Object?>{'type': 'update', 'move_path': null},
              'diff':
                  '--- a/lib/app.dart\n'
                  '+++ b/lib/app.dart\n'
                  '@@ -1 +1,2 @@\n'
                  '-old\n'
                  '+new\n'
                  '+second\n',
            },
          ],
        },
      );

      expect(unifiedDiff, contains('diff --git a/README.md b/README.md'));
      expect(unifiedDiff, contains('diff --git a/lib/app.dart b/lib/app.dart'));
    },
  );

  test('keeps the original path while synthesizing rename metadata', () {
    final files = parser.changedFilesFromSources(
      snapshot: const <String, Object?>{
        'changes': <Object?>[
          <String, Object?>{
            'path': 'lib/old_name.dart',
            'kind': <String, Object?>{
              'type': 'update',
              'move_path': 'lib/new_name.dart',
            },
            'diff':
                '--- a/lib/old_name.dart\n'
                '+++ b/lib/new_name.dart\n'
                '@@ -1 +1 @@\n'
                '-oldName();\n'
                '+newName();\n',
          },
        ],
      },
    );

    expect(files, hasLength(1));
    expect(files.single.path, 'lib/old_name.dart');
    expect(files.single.movePath, 'lib/new_name.dart');
    expect(files.single.additions, 1);
    expect(files.single.deletions, 1);

    final unifiedDiff = parser.unifiedDiffFromSources(
      snapshot: const <String, Object?>{
        'changes': <Object?>[
          <String, Object?>{
            'path': 'lib/old_name.dart',
            'kind': <String, Object?>{
              'type': 'update',
              'move_path': 'lib/new_name.dart',
            },
            'diff':
                '--- a/lib/old_name.dart\n'
                '+++ b/lib/new_name.dart\n'
                '@@ -1 +1 @@\n'
                '-oldName();\n'
                '+newName();\n',
          },
        ],
      },
    );

    expect(unifiedDiff, contains('rename from lib/old_name.dart'));
    expect(unifiedDiff, contains('rename to lib/new_name.dart'));
  });
}
