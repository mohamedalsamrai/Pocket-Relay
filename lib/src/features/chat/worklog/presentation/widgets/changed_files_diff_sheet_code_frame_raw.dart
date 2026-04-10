part of 'changed_files_surface.dart';

class _RawDiffContent extends StatelessWidget {
  const _RawDiffContent({
    required this.diff,
    required this.cards,
    required this.syntaxPalette,
    required this.visibleLines,
  });

  final ChatChangedFileDiffContract diff;
  final TranscriptPalette cards;
  final ChangedFileSyntaxPalette syntaxPalette;
  final List<ChatChangedFileDiffLineContract> visibleLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: visibleLines
          .map(
            (line) => _RawDiffLineView(
              line: line,
              syntaxLanguage: diff.syntaxLanguage,
              cards: cards,
              syntaxPalette: syntaxPalette,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _RawDiffLineView extends StatelessWidget {
  const _RawDiffLineView({
    required this.line,
    required this.syntaxLanguage,
    required this.cards,
    required this.syntaxPalette,
  });

  final ChatChangedFileDiffLineContract line;
  final String? syntaxLanguage;
  final TranscriptPalette cards;
  final ChangedFileSyntaxPalette syntaxPalette;

  @override
  Widget build(BuildContext context) {
    final style = _styleForDiffLine(line.kind, cards);
    final lineDisplay = _DiffLineDisplay.fromContract(line);
    final baseTextStyle = _changedFileCodeTextStyle(
      color: syntaxPalette.base,
      fontSize: 12.2,
      height: 1.45,
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
  final TranscriptPalette cards;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: Text(
        number?.toString() ?? '',
        textAlign: TextAlign.right,
        style: _changedFileCodeTextStyle(
          color: cards.textMuted.withValues(alpha: 0.82),
          fontSize: 11.5,
          height: 1.45,
        ),
      ),
    );
  }
}
