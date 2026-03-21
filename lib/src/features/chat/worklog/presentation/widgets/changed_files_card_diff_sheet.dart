part of 'changed_files_card.dart';

class ChangedFileDiffSheet extends StatefulWidget {
  const ChangedFileDiffSheet({super.key, required this.diff});

  final ChatChangedFileDiffContract diff;

  @override
  State<ChangedFileDiffSheet> createState() => _ChangedFileDiffSheetState();
}

class _ChangedFileDiffSheetState extends State<ChangedFileDiffSheet> {
  bool _showFullDiff = false;

  @override
  Widget build(BuildContext context) {
    final diff = widget.diff;
    final cards = ConversationCardPalette.of(context);
    final pocket = context.pocketPalette;
    final accent = _accentForOperation(diff.operationKind, cards.brightness);
    final visibleLines = _showFullDiff || !diff.hasPreviewLimit
        ? diff.lines
        : diff.lines.take(diff.previewLineLimit).toList(growable: false);

    return FractionallySizedBox(
      heightFactor: 0.96,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth >= 1040
              ? 980.0
              : double.infinity;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: pocket.sheetBackground,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  border: Border.all(color: cards.neutralBorder),
                  boxShadow: [
                    BoxShadow(
                      color: cards.shadow.withValues(
                        alpha: cards.isDark ? 0.34 : 0.14,
                      ),
                      blurRadius: 28,
                      offset: const Offset(0, -12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    const ModalSheetDragHandle(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 14, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  diff.operationLabel.toUpperCase(),
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  diff.fileName,
                                  style: TextStyle(
                                    color: cards.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'monospace',
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  diff.currentPath,
                                  style: TextStyle(
                                    color: cards.textSecondary,
                                    fontSize: 12.5,
                                    fontFamily: 'monospace',
                                    height: 1.35,
                                  ),
                                ),
                                if (diff.renameSummary
                                    case final renameSummary?)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      renameSummary,
                                      style: TextStyle(
                                        color: cards.textMuted,
                                        fontSize: 12,
                                        height: 1.3,
                                      ),
                                    ),
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                      child: Wrap(
                        spacing: 24,
                        runSpacing: 12,
                        children: [
                          _DiffMetric(
                            label: 'Language',
                            value: diff.languageLabel ?? 'Plain text',
                            valueColor: cards.textPrimary,
                          ),
                          _DiffMetric(
                            label: 'Additions',
                            value: '+${diff.stats.additions}',
                            valueColor: tealAccent(cards.brightness),
                          ),
                          _DiffMetric(
                            label: 'Deletions',
                            value: '-${diff.stats.deletions}',
                            valueColor: redAccent(cards.brightness),
                          ),
                          _DiffMetric(
                            label: 'Lines',
                            value: '${diff.lineCount}',
                            valueColor: cards.textPrimary,
                          ),
                        ],
                      ),
                    ),
                    if (diff.hasPreviewLimit)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                        child: _PreviewNotice(
                          cards: cards,
                          accent: accent,
                          previewLineLimit: diff.previewLineLimit,
                          isExpanded: _showFullDiff,
                          onToggle: () {
                            setState(() {
                              _showFullDiff = !_showFullDiff;
                            });
                          },
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                        child: _DiffCodeFrame(
                          diff: diff,
                          cards: cards,
                          accent: accent,
                          visibleLines: visibleLines,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DiffMetric extends StatelessWidget {
  const _DiffMetric({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: cards.textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _PreviewNotice extends StatelessWidget {
  const _PreviewNotice({
    required this.cards,
    required this.accent,
    required this.previewLineLimit,
    required this.isExpanded,
    required this.onToggle,
  });

  final ConversationCardPalette cards;
  final Color accent;
  final int previewLineLimit;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cards.tintedSurface(accent, lightAlpha: 0.05, darkAlpha: 0.1),
        borderRadius: PocketRadii.circular(PocketRadii.md),
        border: Border.all(
          color: cards.accentBorder(accent, lightAlpha: 0.2, darkAlpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                isExpanded
                    ? 'Full diff loaded.'
                    : 'Showing the first $previewLineLimit lines to keep the review surface responsive.',
                style: TextStyle(
                  color: cards.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: onToggle,
              child: Text(isExpanded ? 'Show preview' : 'Load full diff'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiffCodeFrame extends StatelessWidget {
  const _DiffCodeFrame({
    required this.diff,
    required this.cards,
    required this.accent,
    required this.visibleLines,
  });

  final ChatChangedFileDiffContract diff;
  final ConversationCardPalette cards;
  final Color accent;
  final List<ChatChangedFileDiffLineContract> visibleLines;

  @override
  Widget build(BuildContext context) {
    final syntaxPalette = ChangedFileSyntaxPalette(
      base: cards.terminalText,
      comment: cards.textMuted,
      keyword: blueAccent(cards.brightness),
      string: tealAccent(cards.brightness),
      number: amberAccent(cards.brightness),
      type: violetAccent(cards.brightness),
      symbol: pinkAccent(cards.brightness),
      function: const Color(0xFFFCD34D),
      attribute: const Color(0xFFF9A8D4),
      meta: cards.textSecondary,
      variable: const Color(0xFFEAB308),
    );

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
          _DiffEditorBar(diff: diff, cards: cards),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: visibleLines
                                .map(
                                  (line) => _DiffLineView(
                                    line: line,
                                    syntaxLanguage: diff.syntaxLanguage,
                                    cards: cards,
                                    syntaxPalette: syntaxPalette,
                                  ),
                                )
                                .toList(growable: false),
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

class _DiffEditorBar extends StatelessWidget {
  const _DiffEditorBar({required this.diff, required this.cards});

  final ChatChangedFileDiffContract diff;
  final ConversationCardPalette cards;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cards.terminalShell,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          bottom: BorderSide(
            color: cards.neutralBorder.withValues(alpha: 0.38),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            ...const [
              _EditorDot(color: Color(0xFFFB7185)),
              SizedBox(width: 6),
              _EditorDot(color: Color(0xFFFBBF24)),
              SizedBox(width: 6),
              _EditorDot(color: Color(0xFF34D399)),
            ],
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                diff.currentPath,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cards.textSecondary,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  height: 1.2,
                ),
              ),
            ),
            if (diff.languageLabel case final language?)
              Text(
                language,
                style: TextStyle(
                  color: cards.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EditorDot extends StatelessWidget {
  const _EditorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _DiffLineView extends StatelessWidget {
  const _DiffLineView({
    required this.line,
    required this.syntaxLanguage,
    required this.cards,
    required this.syntaxPalette,
  });

  final ChatChangedFileDiffLineContract line;
  final String? syntaxLanguage;
  final ConversationCardPalette cards;
  final ChangedFileSyntaxPalette syntaxPalette;

  @override
  Widget build(BuildContext context) {
    final style = _styleForDiffLine(line.kind, cards);
    final lineDisplay = _DiffLineDisplay.fromContract(line);
    final baseTextStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 12.2,
      height: 1.45,
      color: style.foreground,
      fontWeight: style.fontWeight,
    );

    final contentSpan = lineDisplay.shouldHighlight
        ? ChangedFileSyntaxHighlighter.buildTextSpan(
            source: lineDisplay.content,
            language: syntaxLanguage,
            baseStyle: baseTextStyle,
            palette: syntaxPalette,
          )
        : TextSpan(text: lineDisplay.content, style: baseTextStyle);

    return Container(
      color: style.background,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LineNumberCell(number: line.oldLineNumber, cards: cards),
          const SizedBox(width: 8),
          _LineNumberCell(number: line.newLineNumber, cards: cards),
          const SizedBox(width: 10),
          SizedBox(
            width: 14,
            child: Text(
              lineDisplay.prefix,
              style: baseTextStyle.copyWith(color: style.prefixColor),
            ),
          ),
          const SizedBox(width: 8),
          RichText(text: contentSpan, softWrap: false),
        ],
      ),
    );
  }
}

class _LineNumberCell extends StatelessWidget {
  const _LineNumberCell({required this.number, required this.cards});

  final int? number;
  final ConversationCardPalette cards;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: Text(
        number?.toString() ?? '',
        textAlign: TextAlign.right,
        style: TextStyle(
          color: cards.textMuted.withValues(alpha: 0.82),
          fontFamily: 'monospace',
          fontSize: 11.5,
          height: 1.45,
        ),
      ),
    );
  }
}
