import 'package:pocket_relay/src/core/models/connection_models.dart';

part 'codex_runtime_event_enums.dart';
part 'codex_runtime_event_models.dart';
part 'codex_runtime_event_events_requests.dart';
part 'codex_runtime_event_events_session.dart';
part 'codex_runtime_event_events_status.dart';

sealed class CodexRuntimeEvent {
  const CodexRuntimeEvent({
    required this.createdAt,
    this.threadId,
    this.turnId,
    this.itemId,
    this.requestId,
    this.rawMethod,
    this.rawPayload,
  });

  final DateTime createdAt;
  final String? threadId;
  final String? turnId;
  final String? itemId;
  final String? requestId;
  final String? rawMethod;
  final Object? rawPayload;
}
