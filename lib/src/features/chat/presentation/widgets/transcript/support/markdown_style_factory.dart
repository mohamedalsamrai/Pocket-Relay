import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';

MarkdownStyleSheet buildConversationMarkdownStyle({
  required ThemeData theme,
  required ConversationCardPalette cards,
  required Color accent,
  bool isAssistant = false,
}) {
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: theme.textTheme.bodyLarge?.copyWith(
      color: cards.textPrimary,
      fontSize: isAssistant ? 16 : 14,
      height: isAssistant ? 1.45 : 1.38,
    ),
    codeblockDecoration: BoxDecoration(
      color: cards.codeSurface,
      borderRadius: BorderRadius.circular(12),
    ),
    blockquoteDecoration: BoxDecoration(
      color: cards.tintedSurface(
        accent,
        lightAlpha: 0.08,
        darkAlpha: 0.18,
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    h1: theme.textTheme.headlineSmall?.copyWith(
      color: cards.textPrimary,
      fontSize: isAssistant ? 21 : 19,
    ),
    h2: theme.textTheme.titleLarge?.copyWith(
      color: cards.textPrimary,
      fontSize: isAssistant ? 18 : 16,
    ),
    h3: theme.textTheme.titleMedium?.copyWith(
      color: cards.textPrimary,
      fontSize: isAssistant ? 16 : 15,
    ),
    code: theme.textTheme.bodyMedium?.copyWith(
      color: cards.codeText,
      fontFamily: 'monospace',
      backgroundColor: cards.codeSurface,
      fontSize: isAssistant ? 14 : 13,
    ),
  );
}

MarkdownStyleSheet buildPlanMarkdownStyle({
  required ThemeData theme,
  required ConversationCardPalette cards,
  required Color accent,
}) {
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: theme.textTheme.bodyLarge?.copyWith(
      color: cards.textPrimary,
      fontSize: 14,
      height: 1.38,
    ),
    codeblockDecoration: BoxDecoration(
      color: cards.codeSurface,
      borderRadius: BorderRadius.circular(12),
    ),
    blockquoteDecoration: BoxDecoration(
      color: cards.tintedSurface(accent, lightAlpha: 0.08, darkAlpha: 0.18),
      borderRadius: BorderRadius.circular(12),
    ),
    code: theme.textTheme.bodyMedium?.copyWith(
      color: cards.codeText,
      fontFamily: 'monospace',
      backgroundColor: cards.codeSurface,
      fontSize: 13,
    ),
  );
}
