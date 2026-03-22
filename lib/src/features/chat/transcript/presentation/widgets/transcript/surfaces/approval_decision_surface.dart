import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/chat_request_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_item_primitives.dart';

class ApprovalDecisionSurface extends StatelessWidget {
  const ApprovalDecisionSurface({super.key, required this.request});

  final ChatApprovalRequestContract request;

  @override
  Widget build(BuildContext context) {
    final palette = TranscriptPalette.of(context);
    final accent = _accentColor(Theme.of(context).brightness);

    return TranscriptAnnotation(
      accent: accent,
      header: TranscriptAnnotationHeader(
        icon: _iconData,
        label: request.title,
        accent: accent,
        trailing: TranscriptBadge(
          label: request.resolutionLabel ?? 'resolved',
          color: accent,
        ),
      ),
      child: request.body.trim().isEmpty
          ? const SizedBox.shrink()
          : SelectableText(
              request.body,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 13,
                height: 1.32,
              ),
            ),
    );
  }

  Color _accentColor(Brightness brightness) {
    return switch (request.resolutionLabel) {
      'approved' => Colors.greenAccent.shade400,
      'denied' => Colors.redAccent.shade200,
      _ => amberAccent(brightness),
    };
  }

  IconData get _iconData {
    return switch (request.resolutionLabel) {
      'approved' => Icons.verified_outlined,
      'denied' => Icons.gpp_bad_outlined,
      _ => Icons.gpp_maybe_outlined,
    };
  }
}
