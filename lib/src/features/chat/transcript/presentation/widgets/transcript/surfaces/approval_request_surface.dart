import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/chat_request_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_item_primitives.dart';

class ApprovalRequestSurface extends StatelessWidget {
  const ApprovalRequestSurface({
    super.key,
    required this.request,
    this.onApprove,
    this.onDeny,
  });

  final ChatApprovalRequestContract request;
  final Future<void> Function(String requestId)? onApprove;
  final Future<void> Function(String requestId)? onDeny;

  @override
  Widget build(BuildContext context) {
    final palette = TranscriptPalette.of(context);
    final accent = amberAccent(Theme.of(context).brightness);
    final canRespond =
        !request.isResolved && onApprove != null && onDeny != null;

    return TranscriptAnnotation(
      accent: accent,
      header: TranscriptAnnotationHeader(
        icon: Icons.gpp_maybe_outlined,
        label: request.title,
        accent: accent,
        trailing: request.isResolved
            ? TranscriptBadge(
                label: request.resolutionLabel ?? 'resolved',
                color: accent,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (request.body.trim().isNotEmpty) ...[
            SelectableText(
              request.body,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 13,
                height: 1.32,
              ),
            ),
            const SizedBox(height: PocketSpacing.sm),
          ],
          TranscriptActionRow(
            children: [
              OutlinedButton(
                onPressed: canRespond ? () => onDeny!(request.requestId) : null,
                child: const Text('Deny'),
              ),
              FilledButton(
                onPressed: canRespond
                    ? () => onApprove!(request.requestId)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB45309),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Approve'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
