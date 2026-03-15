import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_card_frame.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';

class SshRemoteLaunchFailedCard extends StatelessWidget {
  const SshRemoteLaunchFailedCard({
    super.key,
    required this.block,
    this.onOpenConnectionSettings,
  });

  final CodexSshRemoteLaunchFailedBlock block;
  final VoidCallback? onOpenConnectionSettings;

  @override
  Widget build(BuildContext context) {
    return SshCardFrame(
      key: const ValueKey('ssh_remote_launch_failed_card'),
      title: 'SSH remote launch failed',
      description:
          'SSH connected to this host, but the remote Codex app-server command did not start. Review the workspace directory and launch command in connection settings.',
      host: block.host,
      port: block.port,
      contextLabel: block.username,
      accent: redAccent(Theme.of(context).brightness),
      icon: Icons.terminal,
      panels: <Widget>[
        SshDetailPanel(label: 'Details', value: block.message),
        SshDetailPanel(
          label: 'Command',
          value: block.command,
          valueKey: const ValueKey('ssh_remote_command_value'),
        ),
      ],
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
