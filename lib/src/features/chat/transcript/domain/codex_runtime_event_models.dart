part of 'codex_runtime_event.dart';

class CodexRuntimeTurnUsage {
  const CodexRuntimeTurnUsage({
    this.inputTokens,
    this.cachedInputTokens,
    this.outputTokens,
    this.raw,
  });

  final int? inputTokens;
  final int? cachedInputTokens;
  final int? outputTokens;
  final Map<String, dynamic>? raw;
}

class CodexRuntimePlanStep {
  const CodexRuntimePlanStep({required this.step, required this.status});

  final String step;
  final CodexRuntimePlanStepStatus status;
}

class CodexRuntimeUserInputOption {
  const CodexRuntimeUserInputOption({
    required this.label,
    required this.description,
  });

  final String label;
  final String description;
}

class CodexRuntimeUserInputQuestion {
  const CodexRuntimeUserInputQuestion({
    required this.id,
    required this.header,
    required this.question,
    this.options = const <CodexRuntimeUserInputOption>[],
    this.isOther = false,
    this.isSecret = false,
  });

  final String id;
  final String header;
  final String question;
  final List<CodexRuntimeUserInputOption> options;
  final bool isOther;
  final bool isSecret;
}

class CodexRuntimeCollabAgentState {
  const CodexRuntimeCollabAgentState({
    required this.status,
    this.message,
  });

  final CodexRuntimeCollabAgentStatus status;
  final String? message;
}

class CodexRuntimeCollabAgentToolCall {
  const CodexRuntimeCollabAgentToolCall({
    required this.tool,
    required this.status,
    required this.senderThreadId,
    required this.receiverThreadIds,
    this.prompt,
    this.model,
    this.reasoningEffort,
    this.agentsStates = const <String, CodexRuntimeCollabAgentState>{},
  });

  final CodexRuntimeCollabAgentTool tool;
  final CodexRuntimeCollabAgentToolCallStatus status;
  final String senderThreadId;
  final List<String> receiverThreadIds;
  final String? prompt;
  final String? model;
  final String? reasoningEffort;
  final Map<String, CodexRuntimeCollabAgentState> agentsStates;
}
