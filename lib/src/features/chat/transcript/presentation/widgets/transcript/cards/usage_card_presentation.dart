class UsagePresentation {
  const UsagePresentation({required this.sections, this.contextWindow});

  factory UsagePresentation.fromBody(String body) {
    final sections = <UsageSection>[];
    String? contextWindow;

    for (final rawLine in body.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }

      final contextMatch = RegExp(
        r'^Context window:\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (contextMatch != null) {
        contextWindow = contextMatch.group(1)?.trim();
        continue;
      }

      final labeledMatch = RegExp(
        r'^(Last|Total):\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (labeledMatch != null) {
        sections.add(
          _parseUsageSection(
            labeledMatch.group(2) ?? '',
            label: labeledMatch.group(1)?.toLowerCase(),
          ),
        );
        continue;
      }

      sections.add(_parseUsageSection(line));
    }

    final compactSections = sections
        .where(
          (section) => section.metrics.isNotEmpty || section.notes.isNotEmpty,
        )
        .toList(growable: false);

    return UsagePresentation(
      sections: compactSections,
      contextWindow: contextWindow,
    );
  }

  final List<UsageSection> sections;
  final String? contextWindow;
}

class UsageSection {
  const UsageSection({required this.metrics, required this.notes, this.label});

  final String? label;
  final List<UsageMetric> metrics;
  final List<String> notes;

  UsageSection copyWith({
    String? label,
    List<UsageMetric>? metrics,
    List<String>? notes,
  }) {
    return UsageSection(
      label: label ?? this.label,
      metrics: metrics ?? this.metrics,
      notes: notes ?? this.notes,
    );
  }

  bool hasSameContent(UsageSection other) {
    if (metrics.length != other.metrics.length ||
        notes.length != other.notes.length) {
      return false;
    }

    for (var index = 0; index < metrics.length; index += 1) {
      if (metrics[index] != other.metrics[index]) {
        return false;
      }
    }

    for (var index = 0; index < notes.length; index += 1) {
      if (notes[index] != other.notes[index]) {
        return false;
      }
    }

    return true;
  }

  String? metricValue(String metricLabel) {
    for (final metric in metrics) {
      if (metric.label == metricLabel) {
        return metric.value;
      }
    }
    return null;
  }

  int? metricIntValue(String metricLabel) {
    return int.tryParse(metricValue(metricLabel) ?? '');
  }
}

class UsageMetric {
  const UsageMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  bool operator ==(Object other) {
    return other is UsageMetric && other.label == label && other.value == value;
  }

  @override
  int get hashCode => Object.hash(label, value);
}

UsageSection _parseUsageSection(String source, {String? label}) {
  final metrics = <UsageMetric>[];
  final notes = <String>[];
  final recognizedMetricLabels = <String>{
    'input',
    'cached',
    'output',
    'reasoning',
    'total',
    'cost',
    'exit',
  };

  for (final rawSegment in source.split('·')) {
    final segment = rawSegment.trim();
    if (segment.isEmpty) {
      continue;
    }

    final match = RegExp(r'^([A-Za-z]+)\s+(.+)$').firstMatch(segment);
    final metricLabel = match?.group(1)?.toLowerCase();
    final metricValue = match?.group(2)?.trim();
    if (metricLabel != null &&
        metricValue != null &&
        metricValue.isNotEmpty &&
        recognizedMetricLabels.contains(metricLabel)) {
      metrics.add(UsageMetric(label: metricLabel, value: metricValue));
      continue;
    }

    notes.add(segment);
  }

  return _normalizeUsageSection(
    UsageSection(label: label, metrics: metrics, notes: notes),
  );
}

UsageSection _normalizeUsageSection(UsageSection section) {
  final input = section.metricIntValue('input');
  final cached = section.metricIntValue('cached') ?? 0;
  final output = section.metricIntValue('output');
  final reasoning = section.metricIntValue('reasoning') ?? 0;

  final hasTokenBreakdown =
      input != null || output != null || cached > 0 || reasoning > 0;
  if (!hasTokenBreakdown) {
    return section;
  }

  final normalizedInput = input == null
      ? null
      : ((input - cached) < 0 ? 0 : (input - cached));
  final normalizedOutput = output == null
      ? null
      : ((output - reasoning) < 0 ? 0 : (output - reasoning));
  final normalizedReasoning = output == null
      ? (reasoning > 0 ? reasoning : null)
      : (reasoning > 0 ? reasoning : 0);
  final blendedTotal =
      (normalizedInput ?? 0) +
      (normalizedOutput ?? 0) +
      (normalizedReasoning ?? 0);

  final normalizedMetrics = <UsageMetric>[
    if (normalizedInput != null)
      UsageMetric(label: 'input', value: '$normalizedInput'),
    if (cached > 0) UsageMetric(label: 'cached', value: '$cached'),
    if (normalizedOutput != null)
      UsageMetric(label: 'output', value: '$normalizedOutput'),
    if (normalizedReasoning != null && normalizedReasoning > 0)
      UsageMetric(label: 'reasoning', value: '$normalizedReasoning'),
    if (normalizedInput != null ||
        normalizedOutput != null ||
        normalizedReasoning != null)
      UsageMetric(label: 'total', value: '$blendedTotal'),
  ];

  return section.copyWith(metrics: normalizedMetrics);
}
