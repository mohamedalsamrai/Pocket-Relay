import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/transcript_chips.dart';

class ChangedFilesCard extends StatefulWidget {
  const ChangedFilesCard({super.key, required this.block});

  final CodexChangedFilesBlock block;

  @override
  State<ChangedFilesCard> createState() => _ChangedFilesCardState();
}

class _ChangedFilesCardState extends State<ChangedFilesCard> {
  bool _showDiff = false;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final accent = amberAccent(Theme.of(context).brightness);
    final files = widget.block.files;
    final diff = widget.block.unifiedDiff?.trim();
    final canToggleDiff = diff != null && diff.isNotEmpty;
    final fileCountLabel = '${files.length} ${files.length == 1 ? 'file' : 'files'}';
    final totalAdditions = files.fold<int>(0, (sum, file) => sum + file.additions);
    final totalDeletions = files.fold<int>(0, (sum, file) => sum + file.deletions);
    final hasStats = totalAdditions > 0 || totalDeletions > 0;

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
                    widget.block.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (widget.block.isRunning)
                  const InlinePulseChip(label: 'updating'),
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
                    '+$totalAdditions -$totalDeletions',
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
                      (file) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: cards.tintedSurface(
                            accent,
                            lightAlpha: 0.08,
                            darkAlpha: 0.14,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: cards.accentBorder(
                              accent,
                              lightAlpha: 0.32,
                              darkAlpha: 0.42,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.insert_drive_file_outlined,
                              size: 13,
                              color: accent,
                            ),
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
                            if (file.additions > 0 || file.deletions > 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                '+${file.additions} -${file.deletions}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cards.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            if (canToggleDiff) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => setState(() => _showDiff = !_showDiff),
                child: Text(_showDiff ? 'Hide diff' : 'Show diff'),
              ),
            ],
            if (_showDiff && diff != null && diff.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cards.terminalBody,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SelectableText(
                  diff,
                  style: TextStyle(
                    color: cards.terminalText,
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    height: 1.28,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
