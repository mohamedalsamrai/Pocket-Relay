part of 'chat_work_log_item_projector.dart';

ChatMcpToolCallStatus _mcpToolCallStatus(
  Map<String, dynamic> snapshot, {
  required bool isRunning,
}) {
  final normalizedStatus = _normalizeIdentifier(
    _stringValue(snapshot['status']),
  );
  return switch (normalizedStatus) {
    'failed' => ChatMcpToolCallStatus.failed,
    'completed' => ChatMcpToolCallStatus.completed,
    'inprogress' || 'in_progress' || 'running' => ChatMcpToolCallStatus.running,
    _ =>
      isRunning
          ? ChatMcpToolCallStatus.running
          : ChatMcpToolCallStatus.completed,
  };
}

String? _normalizedMcpPreview(String? preview, {required String toolName}) {
  final value = _compactSummaryText(preview);
  if (value == null) {
    return null;
  }

  final normalizedValue = _normalizeIdentifier(value);
  if (normalizedValue == _normalizeIdentifier(toolName) ||
      normalizedValue == _normalizeIdentifier('MCP tool call')) {
    return null;
  }
  return value;
}

String? _mcpResultSummary(Object? rawResult) {
  final result = _asObjectValue(rawResult);
  if (result == null) {
    return null;
  }

  final contentText = _contentBlockText(result['content']);
  if (contentText != null) {
    return contentText;
  }

  final structuredSummary = _summarizeMcpValue(
    result['structuredContent'] ?? result['structured_content'],
  );
  if (structuredSummary != null) {
    return structuredSummary;
  }

  final contentItems = result['content'];
  if (contentItems is List && contentItems.isNotEmpty) {
    return contentItems.length == 1
        ? 'Returned 1 content block'
        : 'Returned ${contentItems.length} content blocks';
  }

  return null;
}

String? _contentBlockText(Object? rawContent) {
  if (rawContent is! List) {
    return null;
  }

  for (final entry in rawContent) {
    final object = _asObjectValue(entry);
    final text = _compactSummaryText(
      _firstNonEmptyString(<Object?>[
        object?['text'],
        _asObjectValue(object?['content'])?['text'],
      ]),
    );
    if (text != null) {
      return text;
    }
  }

  return null;
}

String? _summarizeMcpValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    return _compactSummaryText(value);
  }
  if (value is num || value is bool) {
    return value.toString();
  }
  if (value is List) {
    if (value.isEmpty) {
      return null;
    }
    final scalarItems = value
        .map<String?>((item) => _summarizeMcpScalar(item))
        .whereType<String>()
        .toList(growable: false);
    if (scalarItems.isNotEmpty) {
      return _formatCompactItemList(scalarItems, emptyLabel: '');
    }
    return value.length == 1 ? '1 item' : '${value.length} items';
  }
  if (value is Map) {
    final object = Map<String, dynamic>.from(value);
    if (object.isEmpty) {
      return null;
    }
    final scalarEntries = <String>[];
    var omittedCount = 0;
    for (final entry in object.entries) {
      final summarizedValue = _summarizeMcpScalar(entry.value);
      if (summarizedValue == null) {
        continue;
      }
      if (scalarEntries.length == 2) {
        omittedCount++;
        continue;
      }
      scalarEntries.add(
        '${_humanizeFieldName(entry.key)}: $summarizedValue'.trim(),
      );
    }
    if (scalarEntries.isNotEmpty) {
      if (omittedCount > 0) {
        return '${scalarEntries.join(', ')}, +$omittedCount more';
      }
      return scalarEntries.join(', ');
    }
    return object.length == 1 ? '1 parameter' : '${object.length} parameters';
  }
  return null;
}

String? _summarizeMcpScalar(Object? value) {
  return switch (value) {
    final String stringValue => _compactSummaryText(stringValue),
    final num numberValue => numberValue.toString(),
    final bool boolValue => boolValue.toString(),
    _ => null,
  };
}
