part of '../agent_adapter_models.dart';

class AgentAdapterThreadSummary {
  const AgentAdapterThreadSummary({
    required this.id,
    this.preview = '',
    this.ephemeral = false,
    this.modelProvider = '',
    this.createdAt,
    this.updatedAt,
    this.path,
    this.cwd,
    this.promptCount,
    this.name,
    this.sourceKind,
    this.agentNickname,
    this.agentRole,
  });

  final String id;
  final String preview;
  final bool ephemeral;
  final String modelProvider;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? path;
  final String? cwd;
  final int? promptCount;
  final String? name;
  final String? sourceKind;
  final String? agentNickname;
  final String? agentRole;
}

class AgentAdapterHistoryItem {
  const AgentAdapterHistoryItem({
    required this.id,
    this.type,
    this.status,
    required this.raw,
  });

  final String id;
  final String? type;
  final String? status;
  final Map<String, dynamic> raw;
}

class AgentAdapterHistoryTurn {
  const AgentAdapterHistoryTurn({
    required this.id,
    this.threadId,
    this.status,
    this.model,
    this.effort,
    this.stopReason,
    this.usage,
    this.modelUsage,
    this.totalCostUsd,
    this.error,
    this.items = const <AgentAdapterHistoryItem>[],
    required this.raw,
  });

  final String id;
  final String? threadId;
  final String? status;
  final String? model;
  final String? effort;
  final String? stopReason;
  final Map<String, dynamic>? usage;
  final Map<String, dynamic>? modelUsage;
  final double? totalCostUsd;
  final Map<String, dynamic>? error;
  final List<AgentAdapterHistoryItem> items;
  final Map<String, dynamic> raw;
}

class AgentAdapterThreadHistory extends AgentAdapterThreadSummary {
  const AgentAdapterThreadHistory({
    required super.id,
    super.preview = '',
    super.ephemeral = false,
    super.modelProvider = '',
    super.createdAt,
    super.updatedAt,
    super.path,
    super.cwd,
    super.promptCount,
    super.name,
    super.sourceKind,
    super.agentNickname,
    super.agentRole,
    this.turns = const <AgentAdapterHistoryTurn>[],
  });

  final List<AgentAdapterHistoryTurn> turns;
}

class AgentAdapterThreadListPage {
  const AgentAdapterThreadListPage({
    required this.threads,
    required this.nextCursor,
  });

  final List<AgentAdapterThreadSummary> threads;
  final String? nextCursor;
}
