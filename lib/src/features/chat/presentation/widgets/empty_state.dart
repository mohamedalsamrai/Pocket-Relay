import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.isConfigured,
    required this.onConfigure,
  });

  final bool isConfigured;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.86),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: const Color(0xFFD7CDB8)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F4F1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.phone_android,
                          size: 30,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Remote Codex, cleaned up for a phone screen',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isConfigured
                            ? 'Send a prompt below. The app will SSH into your box, run `codex exec --json`, and render messages, commands, and status as cards.'
                            : 'Start by configuring an SSH target. After that, every prompt runs Codex remotely and keeps the output readable on mobile.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.68),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: const [
                          _ChecklistPill('SSH into the dev box'),
                          _ChecklistPill('Run Codex in JSON mode'),
                          _ChecklistPill('Show commands and answers as cards'),
                        ],
                      ),
                      if (!isConfigured) ...[
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: onConfigure,
                          icon: const Icon(Icons.settings),
                          label: const Text('Configure remote'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChecklistPill extends StatelessWidget {
  const _ChecklistPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFE7D8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }
}
