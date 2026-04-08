part of '../agent_adapter_models.dart';

class AgentAdapterModelUpgradeInfo {
  const AgentAdapterModelUpgradeInfo({
    required this.model,
    this.upgradeCopy,
    this.modelLink,
    this.migrationMarkdown,
  });

  final String model;
  final String? upgradeCopy;
  final String? modelLink;
  final String? migrationMarkdown;

  @override
  bool operator ==(Object other) {
    return other is AgentAdapterModelUpgradeInfo &&
        other.model == model &&
        other.upgradeCopy == upgradeCopy &&
        other.modelLink == modelLink &&
        other.migrationMarkdown == migrationMarkdown;
  }

  @override
  int get hashCode =>
      Object.hash(model, upgradeCopy, modelLink, migrationMarkdown);
}

class AgentAdapterReasoningEffortOption {
  const AgentAdapterReasoningEffortOption({
    required this.reasoningEffort,
    required this.description,
  });

  final AgentAdapterReasoningEffort reasoningEffort;
  final String description;

  @override
  bool operator ==(Object other) {
    return other is AgentAdapterReasoningEffortOption &&
        other.reasoningEffort == reasoningEffort &&
        other.description == description;
  }

  @override
  int get hashCode => Object.hash(reasoningEffort, description);
}

class AgentAdapterModel {
  const AgentAdapterModel({
    required this.id,
    required this.model,
    required this.displayName,
    required this.description,
    required this.hidden,
    required this.supportedReasoningEfforts,
    required this.defaultReasoningEffort,
    required this.inputModalities,
    required this.supportsPersonality,
    required this.isDefault,
    this.upgrade,
    this.upgradeInfo,
    this.availabilityNuxMessage,
  });

  final String id;
  final String model;
  final String displayName;
  final String description;
  final bool hidden;
  final List<AgentAdapterReasoningEffortOption> supportedReasoningEfforts;
  final AgentAdapterReasoningEffort defaultReasoningEffort;
  final List<String> inputModalities;
  final bool supportsPersonality;
  final bool isDefault;
  final String? upgrade;
  final AgentAdapterModelUpgradeInfo? upgradeInfo;
  final String? availabilityNuxMessage;

  bool get supportsImageInput => inputModalities.contains('image');

  @override
  bool operator ==(Object other) {
    return other is AgentAdapterModel &&
        other.id == id &&
        other.model == model &&
        other.displayName == displayName &&
        other.description == description &&
        other.hidden == hidden &&
        _listEquals(
          other.supportedReasoningEfforts,
          supportedReasoningEfforts,
        ) &&
        other.defaultReasoningEffort == defaultReasoningEffort &&
        _listEquals(other.inputModalities, inputModalities) &&
        other.supportsPersonality == supportsPersonality &&
        other.isDefault == isDefault &&
        other.upgrade == upgrade &&
        other.upgradeInfo == upgradeInfo &&
        other.availabilityNuxMessage == availabilityNuxMessage;
  }

  @override
  int get hashCode => Object.hash(
    id,
    model,
    displayName,
    description,
    hidden,
    Object.hashAll(supportedReasoningEfforts),
    defaultReasoningEffort,
    Object.hashAll(inputModalities),
    supportsPersonality,
    isDefault,
    upgrade,
    upgradeInfo,
    availabilityNuxMessage,
  );
}

class AgentAdapterModelListPage {
  const AgentAdapterModelListPage({
    required this.models,
    required this.nextCursor,
  });

  final List<AgentAdapterModel> models;
  final String? nextCursor;
}

class AgentAdapterSession {
  const AgentAdapterSession({
    required this.threadId,
    required this.cwd,
    required this.model,
    required this.modelProvider,
    this.reasoningEffort,
    this.thread,
    this.approvalPolicy,
    this.sandbox,
  });

  final String threadId;
  final String cwd;
  final String model;
  final String modelProvider;
  final String? reasoningEffort;
  final AgentAdapterThreadSummary? thread;
  final Object? approvalPolicy;
  final Object? sandbox;
}
