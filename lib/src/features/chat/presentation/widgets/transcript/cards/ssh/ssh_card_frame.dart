import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';

class SshCardFrame extends StatelessWidget {
  const SshCardFrame({
    super.key,
    required this.title,
    required this.description,
    required this.host,
    required this.port,
    required this.accent,
    required this.icon,
    this.contextLabel,
    this.trailing,
    this.panels = const <Widget>[],
    this.actions = const <Widget>[],
  });

  final String title;
  final String description;
  final String host;
  final int port;
  final Color accent;
  final IconData icon;
  final String? contextLabel;
  final Widget? trailing;
  final List<Widget> panels;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final metadata = contextLabel == null
        ? '$host:$port'
        : '$host:$port  •  $contextLabel';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        decoration: BoxDecoration(
          color: cards.tintedSurface(accent, lightAlpha: 0.08, darkAlpha: 0.14),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icon, size: 18, color: accent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailing case final Widget trailingWidget) trailingWidget,
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: cards.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cards.codeSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cards.neutralBorder),
              ),
              child: Text(
                metadata,
                style: TextStyle(
                  color: cards.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final panel in panels) ...[const SizedBox(height: 10), panel],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

class SshDetailPanel extends StatelessWidget {
  const SshDetailPanel({
    super.key,
    required this.label,
    required this.value,
    this.valueKey,
  });

  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: cards.codeSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cards.neutralBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: cards.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            value,
            key: valueKey,
            style: TextStyle(
              color: cards.codeText,
              fontFamily: 'monospace',
              fontSize: 13.2,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
