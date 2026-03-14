import 'package:pocket_relay/src/features/chat/models/conversation_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ConversationEntryCard extends StatelessWidget {
  const ConversationEntryCard({super.key, required this.entry});

  final ConversationEntry entry;

  @override
  Widget build(BuildContext context) {
    return switch (entry.kind) {
      ConversationEntryKind.user => _UserPromptCard(entry: entry),
      ConversationEntryKind.assistant => _AssistantCard(entry: entry),
      ConversationEntryKind.command => _CommandCard(entry: entry),
      ConversationEntryKind.status => _MetaCard(
        entry: entry,
        accent: const Color(0xFF0F766E),
        icon: Icons.info_outline,
      ),
      ConversationEntryKind.error => _MetaCard(
        entry: entry,
        accent: const Color(0xFFB91C1C),
        icon: Icons.warning_amber_rounded,
      ),
      ConversationEntryKind.usage => _MetaCard(
        entry: entry,
        accent: const Color(0xFF7C3AED),
        icon: Icons.analytics_outlined,
      ),
    };
  }
}

class _UserPromptCard extends StatelessWidget {
  const _UserPromptCard({required this.entry});

  final ConversationEntry entry;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          margin: const EdgeInsets.only(left: 56),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F766E),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x220F766E),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                entry.body,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantCard extends StatelessWidget {
  const _AssistantCard({required this.entry});

  final ConversationEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final markdownStyle = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyLarge?.copyWith(
        color: const Color(0xFF1C1917),
        height: 1.5,
      ),
      codeblockDecoration: BoxDecoration(
        color: const Color(0xFFF0EBDE),
        borderRadius: BorderRadius.circular(16),
      ),
      blockquoteDecoration: BoxDecoration(
        color: const Color(0xFFE3F4F1),
        borderRadius: BorderRadius.circular(16),
      ),
      h1: theme.textTheme.headlineSmall,
      h2: theme.textTheme.titleLarge,
      h3: theme.textTheme.titleMedium,
      code: theme.textTheme.bodyMedium?.copyWith(
        fontFamily: 'monospace',
        backgroundColor: const Color(0xFFF0EBDE),
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFD5CCB8)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 20,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.auto_awesome, size: 18, color: Color(0xFF0F766E)),
                SizedBox(width: 8),
                Text(
                  'Codex',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F766E),
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            MarkdownBody(
              data: entry.body,
              selectable: true,
              styleSheet: markdownStyle,
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandCard extends StatelessWidget {
  const _CommandCard({required this.entry});

  final ConversationEntry entry;

  @override
  Widget build(BuildContext context) {
    final output = entry.body.trim().isEmpty
        ? 'Waiting for output…'
        : entry.body;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  const Icon(Icons.terminal, color: Colors.white70, size: 18),
                  Text(
                    entry.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (entry.isRunning)
                    const _StateChip(label: 'running', color: Color(0xFF0F766E))
                  else if (entry.exitCode != null)
                    _StateChip(
                      label: 'exit ${entry.exitCode}',
                      color: entry.exitCode == 0
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFDC2626),
                    ),
                ],
              ),
            ),
            if (entry.isRunning)
              const LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
              ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              decoration: const BoxDecoration(
                color: Color(0xFF111827),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: SelectableText(
                output,
                style: const TextStyle(
                  color: Color(0xFFE5E7EB),
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({
    required this.entry,
    required this.accent,
    required this.icon,
  });

  final ConversationEntry entry;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withValues(alpha: 0.24)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (entry.body.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    SelectableText(
                      entry.body,
                      style: const TextStyle(
                        color: Color(0xFF292524),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
