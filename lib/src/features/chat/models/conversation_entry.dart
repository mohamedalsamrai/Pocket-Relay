enum ConversationEntryKind { user, assistant, command, status, error, usage }

class ConversationEntry {
  const ConversationEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRunning = false,
    this.exitCode,
  });

  final String id;
  final ConversationEntryKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRunning;
  final int? exitCode;

  ConversationEntry copyWith({
    String? id,
    ConversationEntryKind? kind,
    String? title,
    String? body,
    DateTime? createdAt,
    bool? isRunning,
    int? exitCode,
  }) {
    return ConversationEntry(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      isRunning: isRunning ?? this.isRunning,
      exitCode: exitCode ?? this.exitCode,
    );
  }
}
