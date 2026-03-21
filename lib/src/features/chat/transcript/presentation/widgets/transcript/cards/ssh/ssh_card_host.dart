import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/ssh/ssh_auth_failed_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/ssh/ssh_connect_failed_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/ssh/ssh_host_key_mismatch_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/ssh/ssh_remote_launch_failed_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/ssh/ssh_unpinned_host_key_card.dart';

class SshCardHost extends StatelessWidget {
  const SshCardHost({
    super.key,
    required this.block,
    this.onSaveFingerprint,
    this.onOpenConnectionSettings,
  });

  final CodexSshTranscriptBlock block;
  final Future<void> Function(String blockId)? onSaveFingerprint;
  final VoidCallback? onOpenConnectionSettings;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      final CodexSshUnpinnedHostKeyBlock unpinnedBlock =>
        SshUnpinnedHostKeyCard(
          block: unpinnedBlock,
          onSaveFingerprint: onSaveFingerprint,
          onOpenConnectionSettings: onOpenConnectionSettings,
        ),
      final CodexSshConnectFailedBlock connectFailedBlock =>
        SshConnectFailedCard(
          block: connectFailedBlock,
          onOpenConnectionSettings: onOpenConnectionSettings,
        ),
      final CodexSshHostKeyMismatchBlock mismatchBlock =>
        SshHostKeyMismatchCard(
          block: mismatchBlock,
          onOpenConnectionSettings: onOpenConnectionSettings,
        ),
      final CodexSshAuthenticationFailedBlock authFailedBlock =>
        SshAuthFailedCard(
          block: authFailedBlock,
          onOpenConnectionSettings: onOpenConnectionSettings,
        ),
      final CodexSshRemoteLaunchFailedBlock remoteLaunchFailedBlock =>
        SshRemoteLaunchFailedCard(
          block: remoteLaunchFailedBlock,
          onOpenConnectionSettings: onOpenConnectionSettings,
        ),
    };
  }
}
