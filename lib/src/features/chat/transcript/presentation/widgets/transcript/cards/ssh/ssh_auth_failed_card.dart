import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/ssh/ssh_card_frame.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/conversation_card_palette.dart';

class SshAuthFailedCard extends StatelessWidget {
  const SshAuthFailedCard({
    super.key,
    required this.block,
    this.onOpenConnectionSettings,
  });

  final CodexSshAuthenticationFailedBlock block;
  final VoidCallback? onOpenConnectionSettings;

  @override
  Widget build(BuildContext context) {
    final authLabel = switch (block.authMode) {
      AuthMode.password => 'password',
      AuthMode.privateKey => 'private key',
    };

    return SshCardFrame(
      key: const ValueKey('ssh_auth_failed_card'),
      title: 'SSH authentication failed',
      description:
          'SSH could not authenticate as ${block.username}. Check the saved $authLabel configuration in connection settings.',
      host: block.host,
      port: block.port,
      contextLabel: '${block.username}  •  $authLabel',
      accent: redAccent(Theme.of(context).brightness),
      icon: Icons.lock_outline,
      panels: <Widget>[SshDetailPanel(label: 'Details', value: block.message)],
      actions: <Widget>[
        OutlinedButton(
          key: const ValueKey('open_connection_settings'),
          onPressed: onOpenConnectionSettings,
          child: const Text('Connection settings'),
        ),
      ],
    );
  }
}
