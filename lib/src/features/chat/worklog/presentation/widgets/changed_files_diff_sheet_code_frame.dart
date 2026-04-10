part of 'changed_files_surface.dart';

class _DiffCodeFrame extends StatelessWidget {
  const _DiffCodeFrame({
    required this.diff,
    required this.cards,
    required this.accent,
    required this.review,
    required this.showRawPatch,
    required this.onToggleRawPatch,
    required this.visibleLines,
  });

  final ChatChangedFileDiffContract diff;
  final TranscriptPalette cards;
  final Color accent;
  final ChatChangedFileDiffReviewContract review;
  final bool showRawPatch;
  final VoidCallback onToggleRawPatch;
  final List<ChatChangedFileDiffLineContract> visibleLines;

  @override
  Widget build(BuildContext context) {
    const syntaxPalette = ChangedFileSyntaxPalette.changedFileTerminal();
    final shouldShowRawPatch = showRawPatch || review.isEmpty;
    final canToggleRawPatch = diff.lines.isNotEmpty && !review.isEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cards.terminalBody,
        borderRadius: PocketRadii.circular(PocketRadii.xl),
        border: Border.all(
          color: cards.accentBorder(accent, lightAlpha: 0.18, darkAlpha: 0.26),
        ),
      ),
      child: Column(
        children: [
          _DiffEditorBar(
            diff: diff,
            cards: cards,
            showRawPatch: shouldShowRawPatch,
            canToggleRawPatch: canToggleRawPatch,
            onToggleRawPatch: onToggleRawPatch,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final minimumWidth = constraints.maxWidth - 32;
                return Scrollbar(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: minimumWidth),
                        child: SelectionArea(
                          child: shouldShowRawPatch
                              ? _RawDiffContent(
                                  diff: diff,
                                  cards: cards,
                                  syntaxPalette: syntaxPalette,
                                  visibleLines: visibleLines,
                                )
                              : _ReviewDiffContent(
                                  diff: diff,
                                  cards: cards,
                                  accent: accent,
                                  syntaxPalette: syntaxPalette,
                                  review: review,
                                ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
