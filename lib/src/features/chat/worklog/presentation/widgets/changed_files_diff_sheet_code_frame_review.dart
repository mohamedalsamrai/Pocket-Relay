part of 'changed_files_surface.dart';

class _ReviewDiffContent extends StatelessWidget {
  const _ReviewDiffContent({
    required this.diff,
    required this.cards,
    required this.accent,
    required this.syntaxPalette,
    required this.review,
  });

  final ChatChangedFileDiffContract diff;
  final TranscriptPalette cards;
  final Color accent;
  final ChangedFileSyntaxPalette syntaxPalette;
  final ChatChangedFileDiffReviewContract review;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (review.hasMetadata)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: _ReviewMetadataLines(
              cards: cards,
              accent: accent,
              metadataLines: review.metadataLines,
            ),
          ),
        ...review.sections.indexed.map((entry) {
          return Padding(
            padding: EdgeInsets.only(top: entry.$1 == 0 ? 0 : 10),
            child: _ReviewSectionView(
              diff: diff,
              cards: cards,
              accent: accent,
              syntaxPalette: syntaxPalette,
              section: entry.$2,
            ),
          );
        }),
        if (!review.hasSections)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Text(
              'No code preview available.',
              style: TextStyle(
                color: cards.textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
      ],
    );
  }
}

class _ReviewMetadataLines extends StatelessWidget {
  const _ReviewMetadataLines({
    required this.cards,
    required this.accent,
    required this.metadataLines,
  });

  final TranscriptPalette cards;
  final Color accent;
  final List<String> metadataLines;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: accent.withValues(alpha: cards.isDark ? 0.55 : 0.45),
            width: 2.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: metadataLines.indexed
              .map((entry) {
                return Padding(
                  padding: EdgeInsets.only(top: entry.$1 == 0 ? 0 : 4),
                  child: Text(
                    entry.$2,
                    style: TextStyle(
                      color: cards.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _ReviewSectionView extends StatelessWidget {
  const _ReviewSectionView({
    required this.diff,
    required this.cards,
    required this.accent,
    required this.syntaxPalette,
    required this.section,
  });

  final ChatChangedFileDiffContract diff;
  final TranscriptPalette cards;
  final Color accent;
  final ChangedFileSyntaxPalette syntaxPalette;
  final ChatChangedFileDiffReviewSectionContract section;

  @override
  Widget build(BuildContext context) {
    return switch (section.kind) {
      ChatChangedFileDiffReviewSectionKind.hunk => _ReviewHunkSection(
        diff: diff,
        cards: cards,
        accent: accent,
        syntaxPalette: syntaxPalette,
        section: section,
      ),
      ChatChangedFileDiffReviewSectionKind.collapsedGap => _CollapsedGapSection(
        cards: cards,
        hiddenLineCount: section.hiddenLineCount ?? 0,
      ),
      ChatChangedFileDiffReviewSectionKind.binaryMessage =>
        _BinaryMessageSection(
          cards: cards,
          message: section.message ?? 'Binary patch data available.',
        ),
    };
  }
}

class _ReviewHunkSection extends StatelessWidget {
  const _ReviewHunkSection({
    required this.diff,
    required this.cards,
    required this.accent,
    required this.syntaxPalette,
    required this.section,
  });

  final ChatChangedFileDiffContract diff;
  final TranscriptPalette cards;
  final Color accent;
  final ChangedFileSyntaxPalette syntaxPalette;
  final ChatChangedFileDiffReviewSectionContract section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section.label case final label?)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
            child: _HunkSectionLabel(
              cards: cards,
              accent: accent,
              label: label,
            ),
          ),
        ...section.rows.map(
          (row) => _ReviewRowView(
            row: row,
            syntaxLanguage: diff.syntaxLanguage,
            cards: cards,
            syntaxPalette: syntaxPalette,
          ),
        ),
      ],
    );
  }
}

class _HunkSectionLabel extends StatelessWidget {
  const _HunkSectionLabel({
    required this.cards,
    required this.accent,
    required this.label,
  });

  final TranscriptPalette cards;
  final Color accent;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: cards.isDark ? 0.9 : 1),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: cards.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 84,
          height: 1,
          color: cards.neutralBorder.withValues(alpha: 0.45),
        ),
      ],
    );
  }
}

class _CollapsedGapSection extends StatelessWidget {
  const _CollapsedGapSection({
    required this.cards,
    required this.hiddenLineCount,
  });

  final TranscriptPalette cards;
  final int hiddenLineCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 1,
            color: cards.neutralBorder.withValues(alpha: 0.28),
          ),
          const SizedBox(width: 12),
          Text(
            '$hiddenLineCount unchanged lines',
            style: TextStyle(
              color: cards.textMuted,
              fontSize: 11.25,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 1,
            color: cards.neutralBorder.withValues(alpha: 0.28),
          ),
        ],
      ),
    );
  }
}

class _BinaryMessageSection extends StatelessWidget {
  const _BinaryMessageSection({required this.cards, required this.message});

  final TranscriptPalette cards;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: cards.neutralBorder.withValues(alpha: 0.6),
            width: 2.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 0, 2),
        child: Text(
          message,
          style: _changedFileCodeTextStyle(
            color: cards.terminalText,
            fontSize: 12.2,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _ReviewRowView extends StatelessWidget {
  const _ReviewRowView({
    required this.row,
    required this.syntaxLanguage,
    required this.cards,
    required this.syntaxPalette,
  });

  final ChatChangedFileDiffReviewRowContract row;
  final String? syntaxLanguage;
  final TranscriptPalette cards;
  final ChangedFileSyntaxPalette syntaxPalette;

  @override
  Widget build(BuildContext context) {
    final style = _styleForReviewRow(row.kind, cards);
    final baseTextStyle = _changedFileCodeTextStyle(
      color: style.foreground,
      fontSize: 12.2,
      height: 1.5,
    );

    final contentSpan = ChangedFileSyntaxHighlighter.buildTextSpan(
      source: row.content,
      language: syntaxLanguage,
      baseStyle: baseTextStyle,
      palette: syntaxPalette,
    );

    return Container(
      decoration: BoxDecoration(
        color: style.background,
        border: Border(left: BorderSide(color: style.railColor, width: 2.5)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 3, 10, 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              row.lineToken,
              textAlign: TextAlign.right,
              style: _changedFileCodeTextStyle(
                color: style.tokenColor,
                fontSize: 11.25,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          RichText(text: contentSpan, softWrap: false),
        ],
      ),
    );
  }
}
