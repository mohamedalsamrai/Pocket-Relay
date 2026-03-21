part of 'codex_runtime_event.dart';

enum CodexRuntimeSessionState {
  starting,
  ready,
  running,
  waiting,
  stopped,
  error,
}

enum CodexRuntimeThreadState {
  active,
  idle,
  archived,
  closed,
  compacted,
  error,
}

enum CodexRuntimeTurnState { completed, failed, interrupted, cancelled }

enum CodexRuntimePlanStepStatus { pending, inProgress, completed }

enum CodexRuntimeItemStatus { inProgress, completed, failed, declined }

enum CodexRuntimeContentStreamKind {
  assistantText,
  reasoningText,
  reasoningSummaryText,
  planText,
  commandOutput,
  fileChangeOutput,
  unknown,
}

enum CodexRuntimeSessionExitKind { graceful, error }

enum CodexRuntimeErrorClass {
  providerError,
  transportError,
  permissionError,
  validationError,
  unknown,
}

enum CodexRuntimeCollabAgentTool {
  spawnAgent,
  sendInput,
  resumeAgent,
  wait,
  closeAgent,
  unknown,
}

enum CodexRuntimeCollabAgentToolCallStatus {
  inProgress,
  completed,
  failed,
  unknown,
}

enum CodexRuntimeCollabAgentStatus {
  pendingInit,
  running,
  completed,
  errored,
  shutdown,
  notFound,
  unknown,
}

enum CodexCanonicalItemType {
  userMessage,
  assistantMessage,
  reasoning,
  plan,
  commandExecution,
  fileChange,
  mcpToolCall,
  dynamicToolCall,
  collabAgentToolCall,
  webSearch,
  imageView,
  imageGeneration,
  reviewEntered,
  reviewExited,
  contextCompaction,
  error,
  unknown,
}

enum CodexCanonicalRequestType {
  commandExecutionApproval,
  fileChangeApproval,
  applyPatchApproval,
  execCommandApproval,
  permissionsRequestApproval,
  toolUserInput,
  mcpServerElicitation,
  unknown,
}

String codexItemTitle(CodexCanonicalItemType itemType) {
  return switch (itemType) {
    CodexCanonicalItemType.userMessage => 'You',
    CodexCanonicalItemType.assistantMessage => 'Codex',
    CodexCanonicalItemType.reasoning => 'Reasoning',
    CodexCanonicalItemType.plan => 'Proposed plan',
    CodexCanonicalItemType.commandExecution => 'Command',
    CodexCanonicalItemType.fileChange => 'Changed files',
    CodexCanonicalItemType.mcpToolCall => 'MCP tool call',
    CodexCanonicalItemType.dynamicToolCall => 'Tool call',
    CodexCanonicalItemType.collabAgentToolCall => 'Agent tool call',
    CodexCanonicalItemType.webSearch => 'Web search',
    CodexCanonicalItemType.imageView => 'Image view',
    CodexCanonicalItemType.imageGeneration => 'Image generation',
    CodexCanonicalItemType.reviewEntered => 'Review started',
    CodexCanonicalItemType.reviewExited => 'Review finished',
    CodexCanonicalItemType.contextCompaction => 'Context compacted',
    CodexCanonicalItemType.error => 'Error',
    CodexCanonicalItemType.unknown => 'Codex',
  };
}
