part of 'chat_changed_files_item_projector.dart';

List<_ParsedDiffPatch> _parseUnifiedDiff(String? unifiedDiff) {
  final trimmed = unifiedDiff?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return const <_ParsedDiffPatch>[];
  }

  final lines = trimmed.split(RegExp(r'\r?\n'));
  final patches = <_ParsedDiffPatch>[];
  final currentLines = <_DiffLine>[];
  String? diffPath;
  String? newPath;
  String? oldPath;
  String? renameToPath;
  String? renameFromPath;
  int? oldLineCursor;
  int? newLineCursor;
  var additions = 0;
  var deletions = 0;
  var isNewFile = false;
  var isDeletedFile = false;
  var isBinary = false;

  void resetState() {
    currentLines.clear();
    diffPath = null;
    newPath = null;
    oldPath = null;
    renameToPath = null;
    renameFromPath = null;
    oldLineCursor = null;
    newLineCursor = null;
    additions = 0;
    deletions = 0;
    isNewFile = false;
    isDeletedFile = false;
    isBinary = false;
  }

  void commitPatch() {
    if (currentLines.isEmpty) {
      return;
    }

    final resolvedPath =
        renameToPath ??
        newPath ??
        diffPath ??
        renameFromPath ??
        oldPath ??
        'Unknown file';
    final matchedPaths = <String>{
      _normalizeDiffPath(diffPath),
      _normalizeDiffPath(newPath),
      _normalizeDiffPath(oldPath),
      _normalizeDiffPath(renameToPath),
      _normalizeDiffPath(renameFromPath),
      _normalizeDiffPath(resolvedPath),
    }..removeWhere((path) => path.isEmpty);
    final statusLabel = switch ((
      isNewFile,
      isDeletedFile,
      renameToPath != null,
    )) {
      (true, _, _) => 'new file',
      (_, true, _) => 'deleted file',
      (_, _, true) => 'renamed',
      _ => null,
    };

    patches.add(
      _ParsedDiffPatch(
        path: resolvedPath,
        statusLabel: statusLabel,
        additions: additions,
        deletions: deletions,
        isBinary: isBinary,
        matchedPaths: matchedPaths,
        renameFromPath: renameFromPath,
        renameToPath: renameToPath,
        lines: List<_DiffLine>.unmodifiable(currentLines),
      ),
    );
  }

  resetState();

  for (final line in lines) {
    final isOldPathHeader = _isOldDiffPathHeaderLine(line);
    final isNewPathHeader = _isNewDiffPathHeaderLine(line);
    if (line.startsWith('diff --git ')) {
      commitPatch();
      resetState();
      final match = RegExp(r'^diff --git a/(.+?) b/(.+)$').firstMatch(line);
      diffPath = _normalizeDiffPath(match?.group(2));
    } else if (isOldPathHeader &&
        currentLines.isNotEmpty &&
        (oldPath != null ||
            newPath != null ||
            additions > 0 ||
            deletions > 0)) {
      commitPatch();
      resetState();
    }

    if (line.startsWith('new file mode ')) {
      isNewFile = true;
    } else if (line.startsWith('deleted file mode ')) {
      isDeletedFile = true;
    } else if (line.startsWith('rename from ')) {
      renameFromPath = _normalizeDiffPath(
        line.substring('rename from '.length),
      );
    } else if (line.startsWith('rename to ')) {
      renameToPath = _normalizeDiffPath(line.substring('rename to '.length));
    } else if (isOldPathHeader) {
      oldPath = _normalizeDiffPath(line.substring(4).trim());
    } else if (isNewPathHeader) {
      newPath = _normalizeDiffPath(line.substring(4).trim());
    }
    if (line.startsWith('Binary files ') ||
        line.startsWith('GIT binary patch')) {
      isBinary = true;
    }

    final kind = _classifyDiffLine(line, isBinary: isBinary);
    if (kind == _DiffLineKind.hunk) {
      final range = _parseHunkRange(line);
      if (range != null) {
        oldLineCursor = range.oldStart;
        newLineCursor = range.newStart;
      }
    }

    int? oldLineNumber;
    int? newLineNumber;
    switch (kind) {
      case _DiffLineKind.addition:
        newLineNumber = newLineCursor;
        if (newLineCursor != null) {
          newLineCursor = newLineCursor! + 1;
        }
      case _DiffLineKind.deletion:
        oldLineNumber = oldLineCursor;
        if (oldLineCursor != null) {
          oldLineCursor = oldLineCursor! + 1;
        }
      case _DiffLineKind.context:
        if (line.startsWith(' ')) {
          oldLineNumber = oldLineCursor;
          newLineNumber = newLineCursor;
          if (oldLineCursor != null) {
            oldLineCursor = oldLineCursor! + 1;
          }
          if (newLineCursor != null) {
            newLineCursor = newLineCursor! + 1;
          }
        }
      case _DiffLineKind.meta || _DiffLineKind.hunk:
        break;
    }

    currentLines.add(
      _DiffLine(
        text: line,
        kind: kind,
        oldLineNumber: oldLineNumber,
        newLineNumber: newLineNumber,
      ),
    );

    if (kind == _DiffLineKind.addition) {
      additions += 1;
    } else if (kind == _DiffLineKind.deletion) {
      deletions += 1;
    }
  }

  commitPatch();
  return patches;
}

_HunkRange? _parseHunkRange(String line) {
  final match = RegExp(
    r'^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@',
  ).firstMatch(line);
  if (match == null) {
    return null;
  }

  return _HunkRange(
    oldStart: int.parse(match.group(1)!),
    newStart: int.parse(match.group(2)!),
  );
}

String _normalizeDiffPath(String? rawPath) {
  if (rawPath == null) {
    return '';
  }

  final trimmed = rawPath.trim();
  if (trimmed.isEmpty || trimmed == '/dev/null') {
    return '';
  }

  if (trimmed.startsWith('a/') || trimmed.startsWith('b/')) {
    return trimmed.substring(2);
  }

  return trimmed;
}

_DiffLineKind _classifyDiffLine(String line, {required bool isBinary}) {
  if (line.startsWith('@@')) {
    return _DiffLineKind.hunk;
  }

  if (line.startsWith('diff --git ') ||
      line.startsWith('index ') ||
      line.startsWith('new file mode ') ||
      line.startsWith('deleted file mode ') ||
      line.startsWith('rename from ') ||
      line.startsWith('rename to ') ||
      line.startsWith('similarity index ') ||
      line.startsWith(r'\ No newline at end of file') ||
      line.startsWith('Binary files ') ||
      line.startsWith('GIT binary patch')) {
    return _DiffLineKind.meta;
  }

  if (_isOldDiffPathHeaderLine(line) ||
      _isNewDiffPathHeaderLine(line) ||
      isBinary) {
    return _DiffLineKind.meta;
  }

  if (line.startsWith('+')) {
    return _DiffLineKind.addition;
  }

  if (line.startsWith('-')) {
    return _DiffLineKind.deletion;
  }

  return _DiffLineKind.context;
}

bool _isOldDiffPathHeaderLine(String line) {
  return line.startsWith('--- a/') ||
      line.startsWith('--- b/') ||
      line == '--- /dev/null';
}

bool _isNewDiffPathHeaderLine(String line) {
  return line.startsWith('+++ a/') ||
      line.startsWith('+++ b/') ||
      line == '+++ /dev/null';
}

enum _DiffLineKind { meta, hunk, addition, deletion, context }

class _DiffLine {
  const _DiffLine({
    required this.text,
    required this.kind,
    this.oldLineNumber,
    this.newLineNumber,
  });

  final String text;
  final _DiffLineKind kind;
  final int? oldLineNumber;
  final int? newLineNumber;
}

class _ParsedDiffPatch {
  const _ParsedDiffPatch({
    required this.path,
    required this.lines,
    required this.additions,
    required this.deletions,
    required this.isBinary,
    required this.matchedPaths,
    this.renameFromPath,
    this.renameToPath,
    this.statusLabel,
  });

  final String path;
  final List<_DiffLine> lines;
  final int additions;
  final int deletions;
  final bool isBinary;
  final Set<String> matchedPaths;
  final String? renameFromPath;
  final String? renameToPath;
  final String? statusLabel;
}

class _HunkRange {
  const _HunkRange({required this.oldStart, required this.newStart});

  final int oldStart;
  final int newStart;
}
