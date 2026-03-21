import 'package:pocket_relay/src/features/chat/application/codex_historical_conversation.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_models.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';

class CodexHistoricalConversationNormalizer {
  const CodexHistoricalConversationNormalizer();

  CodexHistoricalConversation normalize(CodexAppServerThreadHistory thread) {
    final fallbackCreatedAt =
        thread.createdAt ?? thread.updatedAt ?? DateTime.now();
    return CodexHistoricalConversation(
      threadId: thread.id,
      createdAt: fallbackCreatedAt,
      updatedAt: thread.updatedAt,
      threadName: thread.name,
      sourceKind: thread.sourceKind,
      agentNickname: thread.agentNickname,
      agentRole: thread.agentRole,
      turns: thread.turns
          .map(
            (turn) => _normalizeTurn(
              turn,
              threadId: thread.id,
              fallbackCreatedAt: fallbackCreatedAt,
            ),
          )
          .toList(growable: false),
    );
  }

  CodexHistoricalTurn _normalizeTurn(
    CodexAppServerHistoryTurn turn, {
    required String threadId,
    required DateTime fallbackCreatedAt,
  }) {
    final effectiveThreadId = turn.threadId ?? threadId;
    final createdAt = _eventTimestamp(turn.raw, fallback: fallbackCreatedAt);
    final completedAt = _eventTimestamp(turn.raw, fallback: createdAt);
    return CodexHistoricalTurn(
      id: turn.id,
      threadId: effectiveThreadId,
      createdAt: createdAt,
      completedAt: completedAt,
      state: _turnState(turn.status),
      model: turn.model,
      effort: turn.effort,
      stopReason: turn.stopReason,
      usage: _toTurnUsage(turn.usage),
      modelUsage: turn.modelUsage,
      totalCostUsd: turn.totalCostUsd,
      errorMessage: _asString(turn.error?['message']),
      snapshot: turn.raw,
      entries: turn.items
          .map(
            (item) => _normalizeEntry(
              item,
              threadId: effectiveThreadId,
              turnId: turn.id,
              fallbackCreatedAt: createdAt,
            ),
          )
          .whereType<CodexHistoricalEntry>()
          .toList(growable: false),
    );
  }

  CodexHistoricalEntry? _normalizeEntry(
    CodexAppServerHistoryItem item, {
    required String threadId,
    required String turnId,
    required DateTime fallbackCreatedAt,
  }) {
    final itemType = _canonicalItemType(item.type);
    return CodexHistoricalEntry(
      id: item.id,
      threadId: threadId,
      turnId: turnId,
      createdAt: _eventTimestamp(item.raw, fallback: fallbackCreatedAt),
      itemType: itemType,
      status: _itemStatus(item.status, CodexRuntimeItemStatus.completed),
      title: codexItemTitle(itemType),
      detail: _itemDetail(item.raw),
      snapshot: item.raw,
      collaboration: _collaborationDetails(itemType, item.raw),
    );
  }

  DateTime _eventTimestamp(
    Map<String, dynamic> payload, {
    required DateTime fallback,
  }) {
    return _parseUnixTimestamp(
          payload['createdAt'] ??
              payload['updatedAt'] ??
              payload['completedAt'] ??
              payload['timestamp'],
        ) ??
        fallback;
  }

  DateTime? _parseUnixTimestamp(Object? raw) {
    if (raw is! num) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(
      raw.toInt() * 1000,
      isUtc: true,
    ).toLocal();
  }

  String? _asString(Object? value) {
    return value is String ? value : null;
  }

  int? _asInt(Object? value) {
    return value is num ? value.toInt() : null;
  }

  List<dynamic>? _asList(Object? value) {
    return value is List ? List<dynamic>.from(value) : null;
  }

  Map<String, dynamic>? _asObject(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  CodexCanonicalItemType _canonicalItemType(Object? raw) {
    final normalized = _normalizeType(raw);
    if (normalized.contains('user')) {
      return CodexCanonicalItemType.userMessage;
    }
    if (normalized.contains('agent message') ||
        normalized.contains('assistant')) {
      return CodexCanonicalItemType.assistantMessage;
    }
    if (normalized.contains('reasoning') || normalized.contains('thought')) {
      return CodexCanonicalItemType.reasoning;
    }
    if (normalized.contains('plan') || normalized.contains('todo')) {
      return CodexCanonicalItemType.plan;
    }
    if (normalized.contains('command')) {
      return CodexCanonicalItemType.commandExecution;
    }
    if (normalized.contains('file change') ||
        normalized.contains('patch') ||
        normalized.contains('edit')) {
      return CodexCanonicalItemType.fileChange;
    }
    if (normalized.contains('mcp')) {
      return CodexCanonicalItemType.mcpToolCall;
    }
    if (normalized.contains('dynamic tool')) {
      return CodexCanonicalItemType.dynamicToolCall;
    }
    if (normalized.contains('collab')) {
      return CodexCanonicalItemType.collabAgentToolCall;
    }
    if (normalized.contains('web search')) {
      return CodexCanonicalItemType.webSearch;
    }
    if (normalized.contains('image generation')) {
      return CodexCanonicalItemType.imageGeneration;
    }
    if (normalized.contains('image')) {
      return CodexCanonicalItemType.imageView;
    }
    if (normalized.contains('entered review mode') ||
        normalized.contains('review entered')) {
      return CodexCanonicalItemType.reviewEntered;
    }
    if (normalized.contains('exited review mode') ||
        normalized.contains('review exited')) {
      return CodexCanonicalItemType.reviewExited;
    }
    if (normalized.contains('compact')) {
      return CodexCanonicalItemType.contextCompaction;
    }
    if (normalized.contains('error')) {
      return CodexCanonicalItemType.error;
    }
    return CodexCanonicalItemType.unknown;
  }

  String _normalizeType(Object? raw) {
    final type = _asString(raw);
    if (type == null || type.trim().isEmpty) {
      return 'item';
    }

    return type
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .replaceAll(RegExp(r'[._/-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  CodexRuntimeTurnState _turnState(String? rawStatus) {
    return switch (rawStatus) {
      'failed' => CodexRuntimeTurnState.failed,
      'interrupted' => CodexRuntimeTurnState.interrupted,
      'cancelled' => CodexRuntimeTurnState.cancelled,
      _ => CodexRuntimeTurnState.completed,
    };
  }

  CodexRuntimeItemStatus _itemStatus(
    Object? rawStatus,
    CodexRuntimeItemStatus fallback,
  ) {
    return switch (_asString(rawStatus)) {
      'completed' => CodexRuntimeItemStatus.completed,
      'failed' => CodexRuntimeItemStatus.failed,
      'declined' => CodexRuntimeItemStatus.declined,
      'inProgress' ||
      'in_progress' ||
      'running' => CodexRuntimeItemStatus.inProgress,
      _ => fallback,
    };
  }

  CodexRuntimeTurnUsage? _toTurnUsage(Map<String, dynamic>? usage) {
    if (usage == null) {
      return null;
    }

    return CodexRuntimeTurnUsage(
      inputTokens: _asInt(usage['input_tokens'] ?? usage['inputTokens']),
      cachedInputTokens: _asInt(
        usage['cached_input_tokens'] ?? usage['cachedInputTokens'],
      ),
      outputTokens: _asInt(usage['output_tokens'] ?? usage['outputTokens']),
      raw: usage,
    );
  }

  String? _itemDetail(Map<String, dynamic> item) {
    final nestedResult = _asObject(item['result']);
    return _stringFromCandidates(<Object?>[
      _contentItemsText(_asList(item['content'])),
      item['command'],
      item['title'],
      item['summary'],
      item['text'],
      item['review'],
      item['path'],
      item['prompt'],
      item['query'],
      item['tool'],
      item['revisedPrompt'],
      item['result'],
      nestedResult?['command'],
      nestedResult?['path'],
      nestedResult?['text'],
      item['message'],
    ]);
  }

  String? _stringFromCandidates(List<Object?> candidates) {
    for (final candidate in candidates) {
      final value = _asString(candidate)?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  String? _stringFromCandidatesPreservingWhitespace(List<Object?> candidates) {
    for (final candidate in candidates) {
      final value = _asString(candidate);
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  String? _contentItemsText(List<dynamic>? contentItems) {
    if (contentItems == null) {
      return null;
    }

    final textParts = <String>[];
    for (final item in contentItems) {
      final object = _asObject(item);
      final text = _stringFromCandidatesPreservingWhitespace(<Object?>[
        object?['text'],
        _asObject(object?['content'])?['text'],
      ]);
      if (text != null && text.isNotEmpty) {
        textParts.add(text);
      }
    }

    if (textParts.isEmpty) {
      return null;
    }
    return textParts.join('\n');
  }

  CodexRuntimeCollabAgentToolCall? _collaborationDetails(
    CodexCanonicalItemType itemType,
    Map<String, dynamic> item,
  ) {
    if (itemType != CodexCanonicalItemType.collabAgentToolCall) {
      return null;
    }

    final senderThreadId = _asString(item['senderThreadId']);
    if (senderThreadId == null || senderThreadId.isEmpty) {
      return null;
    }

    final receiverThreadIds = _asList(item['receiverThreadIds'])
        ?.map(_asString)
        .whereType<String>()
        .where((threadId) => threadId.trim().isNotEmpty)
        .toList(growable: false);
    if (receiverThreadIds == null || receiverThreadIds.isEmpty) {
      return null;
    }

    final rawAgentStates = _asObject(item['agentsStates']);
    final agentStates = <String, CodexRuntimeCollabAgentState>{};
    rawAgentStates?.forEach((threadId, rawState) {
      final state = _asObject(rawState);
      final status = _collabAgentStatus(state?['status']);
      if (status == CodexRuntimeCollabAgentStatus.unknown) {
        return;
      }
      agentStates[threadId] = CodexRuntimeCollabAgentState(
        status: status,
        message: _asString(state?['message']),
      );
    });

    return CodexRuntimeCollabAgentToolCall(
      tool: _collabAgentTool(item['tool']),
      status: _collabToolCallStatus(item['status']),
      senderThreadId: senderThreadId,
      receiverThreadIds: receiverThreadIds,
      prompt: _asString(item['prompt']),
      model: _asString(item['model']),
      reasoningEffort: _asString(item['reasoningEffort']),
      agentsStates: agentStates,
    );
  }

  CodexRuntimeCollabAgentTool _collabAgentTool(Object? raw) {
    return switch (_asString(raw)) {
      'spawnAgent' => CodexRuntimeCollabAgentTool.spawnAgent,
      'sendInput' => CodexRuntimeCollabAgentTool.sendInput,
      'resumeAgent' => CodexRuntimeCollabAgentTool.resumeAgent,
      'wait' => CodexRuntimeCollabAgentTool.wait,
      'closeAgent' => CodexRuntimeCollabAgentTool.closeAgent,
      _ => CodexRuntimeCollabAgentTool.unknown,
    };
  }

  CodexRuntimeCollabAgentToolCallStatus _collabToolCallStatus(Object? raw) {
    return switch (_asString(raw)) {
      'inProgress' => CodexRuntimeCollabAgentToolCallStatus.inProgress,
      'completed' => CodexRuntimeCollabAgentToolCallStatus.completed,
      'failed' => CodexRuntimeCollabAgentToolCallStatus.failed,
      _ => CodexRuntimeCollabAgentToolCallStatus.unknown,
    };
  }

  CodexRuntimeCollabAgentStatus _collabAgentStatus(Object? raw) {
    return switch (_asString(raw)) {
      'pendingInit' => CodexRuntimeCollabAgentStatus.pendingInit,
      'running' => CodexRuntimeCollabAgentStatus.running,
      'completed' => CodexRuntimeCollabAgentStatus.completed,
      'errored' => CodexRuntimeCollabAgentStatus.errored,
      'shutdown' => CodexRuntimeCollabAgentStatus.shutdown,
      'notFound' => CodexRuntimeCollabAgentStatus.notFound,
      _ => CodexRuntimeCollabAgentStatus.unknown,
    };
  }
}
