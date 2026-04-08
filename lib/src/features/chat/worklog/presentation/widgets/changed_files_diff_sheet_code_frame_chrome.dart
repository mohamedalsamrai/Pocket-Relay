part of 'changed_files_surface.dart';

class _DiffEditorBar extends StatelessWidget {
  const _DiffEditorBar({
    required this.diff,
    required this.cards,
    required this.showRawPatch,
    required this.canToggleRawPatch,
    required this.onToggleRawPatch,
  });

  final ChatChangedFileDiffContract diff;
  final TranscriptPalette cards;
  final bool showRawPatch;
  final bool canToggleRawPatch;
  final VoidCallback onToggleRawPatch;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cards.terminalShell,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(PocketRadii.xl),
        ),
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
                style: PocketTypography.monospaceStyle(
                  base: const TextStyle(),
                  color: cards.textSecondary,
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
            ),
            if (canToggleRawPatch) ...[
              TextButton(
                onPressed: onToggleRawPatch,
                style: TextButton.styleFrom(
                  foregroundColor: showRawPatch
                      ? cards.terminalText
                      : cards.textMuted,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(showRawPatch ? 'Readable view' : 'Raw patch'),
              ),
              const SizedBox(width: 4),
            ],
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
