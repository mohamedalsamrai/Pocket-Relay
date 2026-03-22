part of 'connection_models.dart';

// Reference snapshot sourced from .reference/codex/codex-rs/core/models.json.
// Keep this app-owned copy narrow to the visible picker models so the settings
// surface can mirror the reference frontend without re-implementing the TUI.
class CodexReferenceModel {
  const CodexReferenceModel({
    required this.id,
    required this.label,
    required this.description,
    required this.defaultReasoningEffort,
    required this.supportedReasoningEfforts,
  });

  final String id;
  final String label;
  final String description;
  final CodexReasoningEffort defaultReasoningEffort;
  final List<CodexReasoningEffort> supportedReasoningEfforts;
}

const List<CodexReferenceModel>
codexReferenceVisibleModels = <CodexReferenceModel>[
  CodexReferenceModel(
    id: 'gpt-5.3-codex',
    label: 'gpt-5.3-codex',
    description: 'Latest frontier agentic coding model.',
    defaultReasoningEffort: CodexReasoningEffort.medium,
    supportedReasoningEfforts: <CodexReasoningEffort>[
      CodexReasoningEffort.low,
      CodexReasoningEffort.medium,
      CodexReasoningEffort.high,
      CodexReasoningEffort.xhigh,
    ],
  ),
  CodexReferenceModel(
    id: 'gpt-5.4',
    label: 'gpt-5.4',
    description: 'Latest frontier agentic coding model.',
    defaultReasoningEffort: CodexReasoningEffort.medium,
    supportedReasoningEfforts: <CodexReasoningEffort>[
      CodexReasoningEffort.low,
      CodexReasoningEffort.medium,
      CodexReasoningEffort.high,
      CodexReasoningEffort.xhigh,
    ],
  ),
  CodexReferenceModel(
    id: 'gpt-5.2-codex',
    label: 'gpt-5.2-codex',
    description: 'Frontier agentic coding model.',
    defaultReasoningEffort: CodexReasoningEffort.medium,
    supportedReasoningEfforts: <CodexReasoningEffort>[
      CodexReasoningEffort.low,
      CodexReasoningEffort.medium,
      CodexReasoningEffort.high,
      CodexReasoningEffort.xhigh,
    ],
  ),
  CodexReferenceModel(
    id: 'gpt-5.1-codex-max',
    label: 'gpt-5.1-codex-max',
    description: 'Codex-optimized flagship for deep and fast reasoning.',
    defaultReasoningEffort: CodexReasoningEffort.medium,
    supportedReasoningEfforts: <CodexReasoningEffort>[
      CodexReasoningEffort.low,
      CodexReasoningEffort.medium,
      CodexReasoningEffort.high,
      CodexReasoningEffort.xhigh,
    ],
  ),
  CodexReferenceModel(
    id: 'gpt-5.2',
    label: 'gpt-5.2',
    description:
        'Latest frontier model with improvements across knowledge, reasoning and coding',
    defaultReasoningEffort: CodexReasoningEffort.medium,
    supportedReasoningEfforts: <CodexReasoningEffort>[
      CodexReasoningEffort.low,
      CodexReasoningEffort.medium,
      CodexReasoningEffort.high,
      CodexReasoningEffort.xhigh,
    ],
  ),
  CodexReferenceModel(
    id: 'gpt-5.1-codex-mini',
    label: 'gpt-5.1-codex-mini',
    description: 'Optimized for codex. Cheaper, faster, but less capable.',
    defaultReasoningEffort: CodexReasoningEffort.medium,
    supportedReasoningEfforts: <CodexReasoningEffort>[
      CodexReasoningEffort.medium,
      CodexReasoningEffort.high,
    ],
  ),
];

CodexReferenceModel get codexDefaultReferenceModel =>
    codexReferenceVisibleModels.first;

CodexReferenceModel? codexReferenceModelForId(String? modelId) {
  final normalized = modelId?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  for (final model in codexReferenceVisibleModels) {
    if (model.id == normalized) {
      return model;
    }
  }

  return null;
}

CodexReferenceModel codexEffectiveReferenceModelForId(String? modelId) {
  return codexReferenceModelForId(modelId) ?? codexDefaultReferenceModel;
}

CodexReasoningEffort? codexNormalizedReasoningEffortForModel(
  String? modelId,
  CodexReasoningEffort? effort,
) {
  if (effort == null) {
    return null;
  }

  final model = codexEffectiveReferenceModelForId(modelId);
  if (model.supportedReasoningEfforts.contains(effort)) {
    return effort;
  }

  return model.defaultReasoningEffort;
}
