import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/utils/thread_utils.dart';
import 'package:flutter/material.dart';

class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({
    super.key,
    required this.profile,
    required this.threadId,
    required this.isBusy,
    required this.onConfigure,
  });

  final ConnectionProfile profile;
  final String? threadId;
  final bool isBusy;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final isConfigured = profile.isReady;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFD7CDB8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConfigured
                          ? profile.label
                          : 'Remote box not configured',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isConfigured
                          ? '${profile.username}@${profile.host}:${profile.port}'
                          : 'Add SSH details, auth, and the remote Codex workspace.',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.64),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: onConfigure,
                icon: const Icon(Icons.settings),
                label: const Text('Configure'),
              ),
            ],
          ),
          if (isConfigured) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoPill(icon: Icons.folder_open, text: profile.workspaceDir),
                _InfoPill(icon: Icons.terminal, text: profile.codexPath),
                _InfoPill(
                  icon: Icons.tag,
                  text: profile.authMode == AuthMode.password
                      ? 'password auth'
                      : 'private key',
                ),
                _InfoPill(
                  icon: isBusy ? Icons.sync : Icons.chat_bubble_outline,
                  text: threadId == null
                      ? 'new thread'
                      : 'thread ${shortenThreadId(threadId)}',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEEE7D8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0F766E)),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
