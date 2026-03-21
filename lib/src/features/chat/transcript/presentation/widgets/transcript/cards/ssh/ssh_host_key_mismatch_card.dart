import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/ssh/ssh_card_frame.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/conversation_card_palette.dart';

class SshHostKeyMismatchCard extends StatelessWidget {
  const SshHostKeyMismatchCard({
    super.key,
    required this.block,
    this.onOpenConnectionSettings,
  });

  final CodexSshHostKeyMismatchBlock block;
  final VoidCallback? onOpenConnectionSettings;

  @override
  Widget build(BuildContext context) {
    return SshCardFrame(
      key: const ValueKey('ssh_host_key_mismatch_card'),
      title: 'SSH host key mismatch',
      description:
          'The pinned host fingerprint does not match the key presented by this server. Review the saved fingerprint before trusting this host.',
      host: block.host,
      port: block.port,
      contextLabel: block.keyType,
      accent: redAccent(Theme.of(context).brightness),
      icon: Icons.gpp_bad_outlined,
      panels: <Widget>[
        SshDetailPanel(
          label: 'Expected fingerprint',
          value: block.expectedFingerprint,
          valueKey: const ValueKey('expected_host_fingerprint_value'),
        ),
        SshDetailPanel(
          label: 'Observed fingerprint',
          value: block.actualFingerprint,
          valueKey: const ValueKey('observed_host_fingerprint_value'),
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
