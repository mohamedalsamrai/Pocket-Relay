import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_radii.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';

class TranscriptAnnotation extends StatelessWidget {
  const TranscriptAnnotation({
    super.key,
    required this.accent,
    required this.child,
    this.maxWidth = 700,
    this.header,
  });

  final Color accent;
  final Widget child;
  final double maxWidth;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 2,
                bottom: 2,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.9),
                    borderRadius: PocketRadii.circular(PocketRadii.pill),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: PocketSpacing.sm + 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (header case final Widget resolvedHeader) ...[
                      resolvedHeader,
                      const SizedBox(height: PocketSpacing.xs),
                    ],
                    child,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TranscriptAnnotationHeader extends StatelessWidget {
  const TranscriptAnnotationHeader({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: accent),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accent,
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (trailing case final Widget trailingWidget) trailingWidget,
      ],
    );
  }
}

class TranscriptCodeInset extends StatelessWidget {
  const TranscriptCodeInset({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: PocketSpacing.md,
      vertical: PocketSpacing.sm,
    ),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final cards = TranscriptPalette.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cards.codeSurface,
        borderRadius: PocketRadii.circular(PocketRadii.sm),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class TranscriptDividerLabel extends StatelessWidget {
  const TranscriptDividerLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cards = TranscriptPalette.of(context);

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: cards.neutralBorder.withValues(alpha: 0.55),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PocketSpacing.xs),
          child: Text(
            label,
            style: TextStyle(
              color: cards.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.45,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: cards.neutralBorder.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

class TranscriptActionRow extends StatelessWidget {
  const TranscriptActionRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: PocketSpacing.sm,
      runSpacing: PocketSpacing.sm,
      children: children,
    );
  }
}
