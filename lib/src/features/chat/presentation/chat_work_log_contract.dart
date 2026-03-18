import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

sealed class ChatWorkLogEntryContract {
  const ChatWorkLogEntryContract({
    required this.id,
    required this.entryKind,
    required this.isRunning,
    required this.exitCode,
    this.turnId,
  });

  final String id;
  final CodexWorkLogEntryKind entryKind;
  final bool isRunning;
  final int? exitCode;
  final String? turnId;
}

final class ChatGenericWorkLogEntryContract extends ChatWorkLogEntryContract {
  const ChatGenericWorkLogEntryContract({
    required super.id,
    required super.entryKind,
    required this.title,
    this.preview,
    super.turnId,
    super.isRunning = false,
    super.exitCode,
  });

  final String title;
  final String? preview;
}

final class ChatReadCommandWorkLogEntryContract
    extends ChatWorkLogEntryContract {
  const ChatReadCommandWorkLogEntryContract({
    required super.id,
    required this.commandText,
    required this.fileName,
    required this.filePath,
    required this.lineStart,
    required this.lineEnd,
    super.turnId,
    super.isRunning = false,
    super.exitCode,
  }) : super(entryKind: CodexWorkLogEntryKind.commandExecution);

  final String commandText;
  final String fileName;
  final String filePath;
  final int lineStart;
  final int lineEnd;

  bool get isSingleLine => lineStart == lineEnd;

  String get lineSummary => isSingleLine
      ? 'Reading line $lineStart'
      : 'Reading lines $lineStart to $lineEnd';
}
