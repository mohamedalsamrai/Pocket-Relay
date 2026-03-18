import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

class TranscriptItemBlockFactory {
  const TranscriptItemBlockFactory();

  static final RegExp _shellCommandWrapperPattern = RegExp(
    r'^(?:\S*\/)?(?:bash|zsh|sh)\s+-(?:lc|c)\s+',
    caseSensitive: false,
  );

  CodexUiBlockKind blockKindForItemType(CodexCanonicalItemType itemType) {
    return switch (itemType) {
      CodexCanonicalItemType.userMessage => CodexUiBlockKind.userMessage,
      CodexCanonicalItemType.commandExecution ||
      CodexCanonicalItemType.webSearch ||
      CodexCanonicalItemType.imageView ||
      CodexCanonicalItemType.imageGeneration ||
      CodexCanonicalItemType.mcpToolCall ||
      CodexCanonicalItemType.dynamicToolCall ||
      CodexCanonicalItemType.collabAgentToolCall =>
        CodexUiBlockKind.workLogEntry,
      CodexCanonicalItemType.reasoning => CodexUiBlockKind.reasoning,
      CodexCanonicalItemType.plan => CodexUiBlockKind.proposedPlan,
      CodexCanonicalItemType.fileChange => CodexUiBlockKind.changedFiles,
      CodexCanonicalItemType.reviewEntered ||
      CodexCanonicalItemType.reviewExited ||
      CodexCanonicalItemType.contextCompaction ||
      CodexCanonicalItemType.unknown => CodexUiBlockKind.status,
      CodexCanonicalItemType.error => CodexUiBlockKind.error,
      _ => CodexUiBlockKind.assistantMessage,
    };
  }

  String defaultItemTitle(CodexCanonicalItemType itemType) {
    return codexItemTitle(itemType);
  }

  String normalizeCommandExecutionTitle(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    final match = _shellCommandWrapperPattern.firstMatch(trimmed);
    if (match == null) {
      return trimmed;
    }

    final normalized = _unwrapShellWrappedCommand(
      trimmed.substring(match.end).trim(),
    ).trim();
    return normalized.isEmpty ? trimmed : normalized;
  }

  CodexWorkLogEntryKind workLogEntryKindFor(CodexCanonicalItemType itemType) {
    return switch (itemType) {
      CodexCanonicalItemType.commandExecution =>
        CodexWorkLogEntryKind.commandExecution,
      CodexCanonicalItemType.webSearch => CodexWorkLogEntryKind.webSearch,
      CodexCanonicalItemType.imageView => CodexWorkLogEntryKind.imageView,
      CodexCanonicalItemType.imageGeneration =>
        CodexWorkLogEntryKind.imageGeneration,
      CodexCanonicalItemType.mcpToolCall => CodexWorkLogEntryKind.mcpToolCall,
      CodexCanonicalItemType.dynamicToolCall =>
        CodexWorkLogEntryKind.dynamicToolCall,
      CodexCanonicalItemType.collabAgentToolCall =>
        CodexWorkLogEntryKind.collabAgentToolCall,
      _ => CodexWorkLogEntryKind.unknown,
    };
  }

  String? workLogPreview(CodexSessionActiveItem item) {
    final body = item.body.trim();
    if (body.isEmpty) {
      return null;
    }

    if (item.itemType == CodexCanonicalItemType.commandExecution) {
      final lines = body
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
      return lines.isEmpty ? null : lines.last;
    }

    return body.split(RegExp(r'\r?\n')).first.trim();
  }

  String _unwrapShellWrappedCommand(String value) {
    if (value.length < 2) {
      return value;
    }

    final quote = value[0];
    if ((quote != "'" && quote != '"') || value[value.length - 1] != quote) {
      return value;
    }

    final inner = value.substring(1, value.length - 1);
    if (quote == "'") {
      return inner.replaceAll("'\"'\"'", "'").replaceAll(r"'\''", "'");
    }

    return inner.replaceAll(r'\"', '"');
  }
}
