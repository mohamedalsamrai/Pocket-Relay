import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_empty_state_body.dart';

class CupertinoEmptyState extends StatelessWidget {
  const CupertinoEmptyState({
    super.key,
    required this.isConfigured,
    required this.onConfigure,
  });

  final bool isConfigured;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    return ChatEmptyStateBody(
      isConfigured: isConfigured,
      onConfigure: onConfigure,
      style: ChatEmptyStateVisualStyle.cupertino,
    );
  }
}
