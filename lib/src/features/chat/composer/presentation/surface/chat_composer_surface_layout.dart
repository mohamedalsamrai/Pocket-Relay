import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';

class ChatComposerSurfaceLayout extends StatelessWidget {
  const ChatComposerSurfaceLayout({
    super.key,
    this.leadingAction,
    required this.input,
    required this.primaryAction,
  });

  final Widget? leadingAction;
  final Widget input;
  final Widget primaryAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;
    final leadingAction = this.leadingAction;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
        child: Row(
          key: const ValueKey('chat_composer_content_row'),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leadingAction != null) ...[
              leadingAction,
              const SizedBox(width: 8),
            ],
            Expanded(child: input),
            const SizedBox(width: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: primaryAction,
            ),
          ],
        ),
      ),
    );
  }
}
