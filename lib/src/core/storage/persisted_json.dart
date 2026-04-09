import 'dart:convert';

enum PersistedJsonIssueKind { malformedJson, notJsonObject, invalidRecord }

final class PersistedJsonIssue {
  const PersistedJsonIssue._({required this.kind, required this.message});

  factory PersistedJsonIssue.malformedJson(String subject) {
    return PersistedJsonIssue._(
      kind: PersistedJsonIssueKind.malformedJson,
      message: 'Persisted $subject is malformed JSON.',
    );
  }

  factory PersistedJsonIssue.notJsonObject(String subject) {
    return PersistedJsonIssue._(
      kind: PersistedJsonIssueKind.notJsonObject,
      message: 'Persisted $subject is not a JSON object.',
    );
  }

  factory PersistedJsonIssue.invalidRecord(
    String subject, {
    String detail = 'is not a valid record.',
  }) {
    return PersistedJsonIssue._(
      kind: PersistedJsonIssueKind.invalidRecord,
      message: 'Persisted $subject $detail',
    );
  }

  final PersistedJsonIssueKind kind;
  final String message;
}

typedef PersistedJsonRecordValidator<T> = String? Function(T value);

final class PersistedJsonReadResult<T> {
  const PersistedJsonReadResult.success(this.value) : issue = null;
  const PersistedJsonReadResult.failure(this.issue) : value = null;

  final T? value;
  final PersistedJsonIssue? issue;

  bool get hasIssue => issue != null;
}

PersistedJsonReadResult<Map<String, Object?>> decodePersistedJsonObject(
  String rawJson, {
  required String subject,
}) {
  final Object decoded;
  try {
    decoded = jsonDecode(rawJson);
  } catch (_) {
    return PersistedJsonReadResult<Map<String, Object?>>.failure(
      PersistedJsonIssue.malformedJson(subject),
    );
  }
  if (decoded is! Map) {
    return PersistedJsonReadResult<Map<String, Object?>>.failure(
      PersistedJsonIssue.notJsonObject(subject),
    );
  }
  return PersistedJsonReadResult<Map<String, Object?>>.success(
    Map<String, Object?>.from(decoded),
  );
}

PersistedJsonReadResult<T> decodePersistedJsonRecord<T>(
  String rawJson, {
  required String subject,
  required T Function(Map<String, Object?> json) decode,
  PersistedJsonRecordValidator<T>? validate,
  String invalidRecordDetail = 'is not a valid record.',
}) {
  final objectResult = decodePersistedJsonObject(rawJson, subject: subject);
  if (objectResult.issue case final issue?) {
    return PersistedJsonReadResult<T>.failure(issue);
  }

  try {
    final value = decode(objectResult.value!);
    final validationIssue = validate?.call(value);
    if (validationIssue != null) {
      return PersistedJsonReadResult<T>.failure(
        PersistedJsonIssue.invalidRecord(subject, detail: validationIssue),
      );
    }
    return PersistedJsonReadResult<T>.success(value);
  } catch (_) {
    return PersistedJsonReadResult<T>.failure(
      PersistedJsonIssue.invalidRecord(subject, detail: invalidRecordDetail),
    );
  }
}
