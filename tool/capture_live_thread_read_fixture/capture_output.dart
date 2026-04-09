import 'dart:convert';
import 'dart:io';

Future<void> writeJsonFile({
  required String path,
  required Object? content,
}) async {
  final outputFile = File(path);
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(content)}\n',
  );
}

Map<String, Object?> buildThreadCaptureSummary(
  Map<String, dynamic> payload, {
  required String fallbackThreadId,
}) {
  final turns = extractTurns(payload);
  return <String, Object?>{
    'threadId': extractThreadId(payload) ?? fallbackThreadId,
    'turnCount': turns.length,
    'itemCountsByTurn': turns
        .map((turn) {
          final items = turn['items'];
          return items is List ? items.length : 0;
        })
        .toList(growable: false),
  };
}

List<Map<String, dynamic>> extractTurns(Map<String, dynamic> payload) {
  final thread = extractThreadObject(payload);
  return asObjectList(thread?['turns']) ??
      asObjectList(payload['turns']) ??
      const <Map<String, dynamic>>[];
}

Map<String, dynamic>? extractThreadObject(Map<String, dynamic> payload) {
  final rawThread = payload['thread'];
  if (rawThread is Map) {
    return Map<String, dynamic>.from(rawThread);
  }
  return null;
}

String? extractThreadId(Map<String, dynamic> payload) {
  final thread = extractThreadObject(payload);
  return asNonEmptyString(thread?['id']) ??
      asNonEmptyString(payload['threadId']) ??
      asNonEmptyString(payload['id']);
}

List<Map<String, dynamic>>? asObjectList(Object? value) {
  if (value is! List) {
    return null;
  }
  return value
      .whereType<Map>()
      .map((entry) => Map<String, dynamic>.from(entry))
      .toList(growable: false);
}

String? asNonEmptyString(Object? value) {
  final normalized = value is String ? value.trim() : null;
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}
