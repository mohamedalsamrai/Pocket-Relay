import 'package:flutter/material.dart';

class ChatComposerAttachmentSummaryList extends StatelessWidget {
  const ChatComposerAttachmentSummaryList({super.key, required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final entry in labels.indexed)
          Padding(
            padding: EdgeInsets.only(top: entry.$1 == 0 ? 0 : 4),
            child: _ChatComposerAttachmentSummary(label: entry.$2),
          ),
      ],
    );
  }
}

class _ChatComposerAttachmentSummary extends StatelessWidget {
  const _ChatComposerAttachmentSummary({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.image_outlined,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
