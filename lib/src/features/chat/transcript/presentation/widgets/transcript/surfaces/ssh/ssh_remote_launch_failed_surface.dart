import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/ssh/ssh_surface_frame.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';

class SshRemoteLaunchFailedSurface extends StatelessWidget {
  const SshRemoteLaunchFailedSurface({
    super.key,
    required this.block,
    this.onOpenConnectionSettings,
  });

  final CodexSshRemoteLaunchFailedBlock block;
  final VoidCallback? onOpenConnectionSettings;

  @override
  Widget build(BuildContext context) {
    return SshSurfaceFrame(
      key: const ValueKey('ssh_remote_launch_failed_surface'),
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
