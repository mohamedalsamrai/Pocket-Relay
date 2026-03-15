import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/turn_elapsed_footer.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/transcript_chips.dart';

class ChangedFilesCard extends StatelessWidget {
  const ChangedFilesCard({super.key, required this.block, this.turnTimer});

  final CodexChangedFilesBlock block;
  final CodexSessionTurnTimer? turnTimer;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final accent = amberAccent(Theme.of(context).brightness);
    final patches = _parseUnifiedDiff(block.unifiedDiff);
    final files = _displayFiles(block.files, patches);
    final headerStats = _resolveHeaderStats(files: files, patches: patches);
    final fileCountLabel =
        '${files.length} ${files.length == 1 ? 'file' : 'files'}';
    final hasStats = headerStats.additions > 0 || headerStats.deletions > 0;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        decoration: BoxDecoration(
          color: cards.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cards.accentBorder(accent)),
          boxShadow: [
            BoxShadow(
              color: cards.shadow.withValues(alpha: cards.isDark ? 0.18 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.drive_file_rename_outline, size: 16, color: accent),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    block.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (block.isRunning) const InlinePulseChip(label: 'updating'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  fileCountLabel,
                  style: TextStyle(
                    color: cards.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                if (hasStats) ...[
                  const SizedBox(width: 8),
                  Text(
                    '+${headerStats.additions} -${headerStats.deletions}',
                    style: TextStyle(color: cards.textSecondary, fontSize: 12),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (files.isEmpty)
              Text(
                'Waiting for changed files…',
                style: TextStyle(color: cards.textMuted),
              )
            else
              Column(
                children: files
                    .map(
                      (file) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _ChangedFileRow(
                          file: file,
                          patch: _patchForFile(
                            file,
                            patches,
                            totalFiles: files.length,
                          ),
                          accent: accent,
                          cards: cards,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            if (turnTimer != null)
              TurnElapsedFooter(turnTimer: turnTimer!, accent: accent),
          ],
        ),
      ),
    );
  }
}

class _ChangedFileRow extends StatelessWidget {
  const _ChangedFileRow({
    required this.file,
    required this.patch,
    required this.accent,
    required this.cards,
  });

  final CodexChangedFile file;
  final _ParsedDiffPatch? patch;
  final Color accent;
  final ConversationCardPalette cards;

  bool get _canOpenPatch => patch != null;

  @override
  Widget build(BuildContext context) {
    final stats = _resolveFileStats(file: file, patch: patch);
    final body = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cards.tintedSurface(accent, lightAlpha: 0.08, darkAlpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cards.accentBorder(accent, lightAlpha: 0.32, darkAlpha: 0.42),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_outlined, size: 13, color: accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              file.path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontFamily: 'monospace',
                color: cards.textSecondary,
                height: 1.2,
              ),
            ),
          ),
          if (stats.additions > 0 || stats.deletions > 0) ...[
            const SizedBox(width: 8),
            Text(
              '+${stats.additions} -${stats.deletions}',
              style: TextStyle(fontSize: 11, color: cards.textMuted),
            ),
          ],
          const SizedBox(width: 8),
          _ChangedFileActionChip(
            label: _canOpenPatch ? 'View diff' : 'No patch',
            accent: accent,
            cards: cards,
            isEnabled: _canOpenPatch,
          ),
        ],
      ),
    );

    if (!_canOpenPatch) {
      return body;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDiffSheet(context, file: file, patch: patch!),
        child: body,
      ),
    );
  }

  Future<void> _openDiffSheet(
    BuildContext context, {
    required CodexChangedFile file,
    required _ParsedDiffPatch patch,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ChangedFileDiffSheet(file: file, patch: patch, accent: accent);
      },
    );
  }
}

class _ChangedFileActionChip extends StatelessWidget {
  const _ChangedFileActionChip({
    required this.label,
    required this.accent,
    required this.cards,
    required this.isEnabled,
  });

  final String label;
  final Color accent;
  final ConversationCardPalette cards;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final chipAccent = isEnabled ? accent : cards.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cards.tintedSurface(
          chipAccent,
          lightAlpha: isEnabled ? 0.12 : 0.05,
          darkAlpha: isEnabled ? 0.22 : 0.1,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: cards.accentBorder(
            chipAccent,
            lightAlpha: isEnabled ? 0.3 : 0.18,
            darkAlpha: isEnabled ? 0.42 : 0.24,
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: chipAccent,
        ),
      ),
    );
  }
}

class _ChangedFileDiffSheet extends StatefulWidget {
  const _ChangedFileDiffSheet({
    required this.file,
    required this.patch,
    required this.accent,
  });

  final CodexChangedFile file;
  final _ParsedDiffPatch patch;
  final Color accent;

  @override
  State<_ChangedFileDiffSheet> createState() => _ChangedFileDiffSheetState();
}

class _ChangedFileDiffSheetState extends State<_ChangedFileDiffSheet> {
  static const int _previewLineLimit = 320;

  bool _showFullDiff = false;

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    final patch = widget.patch;
    final accent = widget.accent;
    final cards = ConversationCardPalette.of(context);
    final pocket = context.pocketPalette;
    final statusLabel = patch.statusLabel;
    final stats = _resolveFileStats(file: file, patch: patch);
    final hasPreviewLimit = patch.lines.length > _previewLineLimit;
    final visibleLines = _showFullDiff || !hasPreviewLimit
        ? patch.lines
        : patch.lines.take(_previewLineLimit).toList(growable: false);

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: pocket.sheetBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: cards.neutralBorder),
          boxShadow: [
            BoxShadow(
              color: cards.shadow.withValues(alpha: cards.isDark ? 0.34 : 0.14),
              blurRadius: 24,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: pocket.dragHandle,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.path,
                          style: TextStyle(
                            color: cards.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _SheetChip(
                              label: '+${stats.additions} additions',
                              accent: tealAccent(cards.brightness),
                              cards: cards,
                            ),
                            _SheetChip(
                              label: '-${stats.deletions} deletions',
                              accent: redAccent(cards.brightness),
                              cards: cards,
                            ),
                            _SheetChip(
                              label: '${patch.lines.length} lines',
                              accent: neutralAccent(cards.brightness),
                              cards: cards,
                            ),
                            if (statusLabel != null && statusLabel.isNotEmpty)
                              _SheetChip(
                                label: statusLabel,
                                accent: accent,
                                cards: cards,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close diff',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: cards.textMuted),
                  ),
                ],
              ),
            ),
            if (hasPreviewLimit)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: cards.tintedSurface(
                      accent,
                      lightAlpha: 0.06,
                      darkAlpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: cards.accentBorder(
                        accent,
                        lightAlpha: 0.22,
                        darkAlpha: 0.3,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _showFullDiff
                              ? 'Full diff loaded.'
                              : 'Showing the first $_previewLineLimit lines to keep the sheet responsive.',
                          style: TextStyle(
                            color: cards.textSecondary,
                            fontSize: 11.5,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showFullDiff = !_showFullDiff;
                          });
                        },
                        child: Text(
                          _showFullDiff ? 'Show preview' : 'Load full diff',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cards.terminalBody,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: cards.accentBorder(
                        accent,
                        lightAlpha: 0.18,
                        darkAlpha: 0.28,
                      ),
                    ),
                  ),
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: SelectionArea(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: visibleLines
                                .map(
                                  (line) =>
                                      _DiffLineView(line: line, cards: cards),
                                )
                                .toList(growable: false),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetChip extends StatelessWidget {
  const _SheetChip({
    required this.label,
    required this.accent,
    required this.cards,
  });

  final String label;
  final Color accent;
  final ConversationCardPalette cards;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cards.tintedSurface(accent, lightAlpha: 0.08, darkAlpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: cards.accentBorder(accent, lightAlpha: 0.26, darkAlpha: 0.36),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _DiffLineView extends StatelessWidget {
  const _DiffLineView({required this.line, required this.cards});

  final _DiffLine line;
  final ConversationCardPalette cards;

  @override
  Widget build(BuildContext context) {
    final style = _styleForLine(line.kind, cards);
    return Container(
      color: style.background,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Text(
        line.text,
        softWrap: false,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11.8,
          height: 1.38,
          color: style.foreground,
          fontWeight: style.fontWeight,
        ),
      ),
    );
  }

  _DiffLineStyle _styleForLine(
    _DiffLineKind kind,
    ConversationCardPalette cards,
  ) {
    return switch (kind) {
      _DiffLineKind.addition => _DiffLineStyle(
        background: Color.alphaBlend(
          tealAccent(
            cards.brightness,
          ).withValues(alpha: cards.isDark ? 0.18 : 0.12),
          cards.terminalBody,
        ),
        foreground: cards.terminalText,
      ),
      _DiffLineKind.deletion => _DiffLineStyle(
        background: Color.alphaBlend(
          redAccent(
            cards.brightness,
          ).withValues(alpha: cards.isDark ? 0.2 : 0.12),
          cards.terminalBody,
        ),
        foreground: cards.terminalText,
      ),
      _DiffLineKind.hunk => _DiffLineStyle(
        background: Color.alphaBlend(
          blueAccent(
            cards.brightness,
          ).withValues(alpha: cards.isDark ? 0.18 : 0.12),
          cards.terminalBody,
        ),
        foreground: blueAccent(
          cards.brightness,
        ).withValues(alpha: cards.isDark ? 0.92 : 1),
        fontWeight: FontWeight.w700,
      ),
      _DiffLineKind.meta => _DiffLineStyle(
        background: Color.alphaBlend(
          amberAccent(
            cards.brightness,
          ).withValues(alpha: cards.isDark ? 0.12 : 0.08),
          cards.terminalBody,
        ),
        foreground: cards.textSecondary,
      ),
      _DiffLineKind.context => _DiffLineStyle(
        background: cards.terminalBody,
        foreground: cards.terminalText,
      ),
    };
  }
}

class _DiffLineStyle {
  const _DiffLineStyle({
    required this.background,
    required this.foreground,
    this.fontWeight = FontWeight.w500,
  });

  final Color background;
  final Color foreground;
  final FontWeight fontWeight;
}

List<CodexChangedFile> _displayFiles(
  List<CodexChangedFile> files,
  List<_ParsedDiffPatch> patches,
) {
  if (files.isNotEmpty) {
    return files;
  }

  return patches
      .map(
        (patch) => CodexChangedFile(
          path: patch.path,
          additions: patch.additions,
          deletions: patch.deletions,
        ),
      )
      .toList(growable: false);
}

_ParsedDiffPatch? _patchForFile(
  CodexChangedFile file,
  List<_ParsedDiffPatch> patches, {
  required int totalFiles,
}) {
  if (patches.isEmpty) {
    return null;
  }

  final normalizedPath = _normalizeDiffPath(file.path);
  for (final patch in patches) {
    if (patch.matchedPaths.contains(normalizedPath)) {
      return patch;
    }
  }

  if (totalFiles == 1 &&
      patches.length == 1 &&
      patches.single.matchedPaths.isEmpty) {
    return patches.single;
  }

  return null;
}

_DiffStats _resolveHeaderStats({
  required List<CodexChangedFile> files,
  required List<_ParsedDiffPatch> patches,
}) {
  final fileStats = files.fold<_DiffStats>(
    const _DiffStats(),
    (sum, file) => _DiffStats(
      additions: sum.additions + file.additions,
      deletions: sum.deletions + file.deletions,
    ),
  );
  if (fileStats.additions > 0 || fileStats.deletions > 0) {
    return fileStats;
  }

  return patches.fold<_DiffStats>(
    const _DiffStats(),
    (sum, patch) => _DiffStats(
      additions: sum.additions + patch.additions,
      deletions: sum.deletions + patch.deletions,
    ),
  );
}

_DiffStats _resolveFileStats({
  required CodexChangedFile file,
  required _ParsedDiffPatch? patch,
}) {
  if (file.additions > 0 || file.deletions > 0 || patch == null) {
    return _DiffStats(additions: file.additions, deletions: file.deletions);
  }

  return _DiffStats(additions: patch.additions, deletions: patch.deletions);
}

List<_ParsedDiffPatch> _parseUnifiedDiff(String? unifiedDiff) {
  final trimmed = unifiedDiff?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return const <_ParsedDiffPatch>[];
  }

  final lines = trimmed.split(RegExp(r'\r?\n'));
  final patches = <_ParsedDiffPatch>[];
  final currentLines = <String>[];
  String? diffPath;
  String? newPath;
  String? oldPath;
  String? renameToPath;
  String? renameFromPath;
  var additions = 0;
  var deletions = 0;
  var isNewFile = false;
  var isDeletedFile = false;

  void resetState() {
    currentLines.clear();
    diffPath = null;
    newPath = null;
    oldPath = null;
    renameToPath = null;
    renameFromPath = null;
    additions = 0;
    deletions = 0;
    isNewFile = false;
    isDeletedFile = false;
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
        rawPatch: currentLines.join('\n'),
        statusLabel: statusLabel,
        additions: additions,
        deletions: deletions,
        matchedPaths: matchedPaths,
        lines: currentLines
            .map((line) => _DiffLine(text: line, kind: _classifyDiffLine(line)))
            .toList(growable: false),
      ),
    );
  }

  resetState();

  for (final line in lines) {
    if (line.startsWith('diff --git ')) {
      commitPatch();
      resetState();
      final match = RegExp(r'^diff --git a/(.+?) b/(.+)$').firstMatch(line);
      diffPath = _normalizeDiffPath(match?.group(2));
    } else if (line.startsWith('--- ') &&
        currentLines.isNotEmpty &&
        (oldPath != null ||
            newPath != null ||
            additions > 0 ||
            deletions > 0)) {
      commitPatch();
      resetState();
    }

    currentLines.add(line);

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
    } else if (line.startsWith('--- ')) {
      oldPath = _normalizeDiffPath(line.substring(4).trim());
    } else if (line.startsWith('+++ ')) {
      newPath = _normalizeDiffPath(line.substring(4).trim());
    } else if (line.startsWith('+') && !line.startsWith('+++')) {
      additions += 1;
    } else if (line.startsWith('-') && !line.startsWith('---')) {
      deletions += 1;
    }
  }

  commitPatch();
  return patches;
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

_DiffLineKind _classifyDiffLine(String line) {
  if (line.startsWith('@@')) {
    return _DiffLineKind.hunk;
  }

  if (line.startsWith('diff --git ') ||
      line.startsWith('index ') ||
      line.startsWith('--- ') ||
      line.startsWith('+++ ') ||
      line.startsWith('new file mode ') ||
      line.startsWith('deleted file mode ') ||
      line.startsWith('rename from ') ||
      line.startsWith('rename to ') ||
      line.startsWith('similarity index ')) {
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

enum _DiffLineKind { meta, hunk, addition, deletion, context }

class _DiffLine {
  const _DiffLine({required this.text, required this.kind});

  final String text;
  final _DiffLineKind kind;
}

class _ParsedDiffPatch {
  const _ParsedDiffPatch({
    required this.path,
    required this.rawPatch,
    required this.lines,
    required this.additions,
    required this.deletions,
    required this.matchedPaths,
    this.statusLabel,
  });

  final String path;
  final String rawPatch;
  final List<_DiffLine> lines;
  final int additions;
  final int deletions;
  final Set<String> matchedPaths;
  final String? statusLabel;
}

class _DiffStats {
  const _DiffStats({this.additions = 0, this.deletions = 0});

  final int additions;
  final int deletions;
}
