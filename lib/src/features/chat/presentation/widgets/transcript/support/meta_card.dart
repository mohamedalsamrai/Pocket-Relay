import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';

class MetaCard extends StatelessWidget {
  const MetaCard({
    super.key,
    required this.title,
    required this.body,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String body;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
        decoration: BoxDecoration(
          color: cards.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cards.accentBorder(accent)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, color: accent, size: 15),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: title,
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (body.trim().isNotEmpty)
                      TextSpan(
                        text: '  ${body.trim()}',
                        style: TextStyle(
                          color: cards.textSecondary,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                  ],
                ),
                style: TextStyle(color: cards.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
