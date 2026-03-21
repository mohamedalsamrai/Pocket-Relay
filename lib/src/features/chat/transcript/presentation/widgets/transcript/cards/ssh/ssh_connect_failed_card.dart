import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/ssh/ssh_card_frame.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/conversation_card_palette.dart';

class SshConnectFailedCard extends StatelessWidget {
  const SshConnectFailedCard({
    super.key,
    required this.block,
    this.onOpenConnectionSettings,
  });

  final CodexSshConnectFailedBlock block;
  final VoidCallback? onOpenConnectionSettings;

  @override
  Widget build(BuildContext context) {
    return SshCardFrame(
      key: const ValueKey('ssh_connect_failed_card'),
      title: 'SSH connection failed',
      description:
          'Pocket Relay could not open an SSH connection to this host. Check the saved host, port, and network reachability in connection settings.',
      host: block.host,
      port: block.port,
      accent: redAccent(Theme.of(context).brightness),
      icon: Icons.portable_wifi_off_outlined,
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
