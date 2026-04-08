part of '../fake_codex_app_server_client.dart';

mixin _FakeCodexAppServerClientState on CodexAppServerClient {
  final _eventsController = StreamController<CodexAppServerEvent>.broadcast();

  int connectCalls = 0;
  int startSessionCalls = 0;
  final List<
    ({
      String threadId,
      String? path,
      String? cwd,
      String? model,
      String? modelProvider,
      bool? ephemeral,
      bool persistExtendedHistory,
    })
  >
  forkThreadRequests =
      <
        ({
          String threadId,
          String? path,
          String? cwd,
          String? model,
          String? modelProvider,
          bool? ephemeral,
          bool persistExtendedHistory,
        })
      >[];
  final List<
    ({
      String? cwd,
      String? model,
      CodexReasoningEffort? reasoningEffort,
      String? resumeThreadId,
    })
  >
  startSessionRequests =
      <
        ({
          String? cwd,
          String? model,
          CodexReasoningEffort? reasoningEffort,
          String? resumeThreadId,
        })
      >[];
  final List<String> readThreadCalls = <String>[];
  final List<({String threadId, int numTurns})> rollbackThreadCalls =
      <({String threadId, int numTurns})>[];
  final List<({String? cursor, int? limit})> listThreadCalls =
      <({String? cursor, int? limit})>[];
  final List<({String? cursor, int? limit, bool? includeHidden})>
  listModelCalls = <({String? cursor, int? limit, bool? includeHidden})>[];
  final List<String> sentMessages = <String>[];
  final List<
    ({
      String threadId,
      CodexAppServerTurnInput input,
      String text,
      String? model,
      CodexReasoningEffort? effort,
    })
  >
  sentTurns =
      <
        ({
          String threadId,
          CodexAppServerTurnInput input,
          String text,
          String? model,
          CodexReasoningEffort? effort,
        })
      >[];
  final List<String> steeredMessages = <String>[];
  final List<
    ({
      String threadId,
      String turnId,
      CodexAppServerTurnInput input,
      String text,
    })
  >
  steeredTurns =
      <
        ({
          String threadId,
          String turnId,
          CodexAppServerTurnInput input,
          String text,
        })
      >[];
  final List<({String? threadId, String? turnId})> abortTurnCalls =
      <({String? threadId, String? turnId})>[];
  final List<({String requestId, bool approved})> approvalDecisions =
      <({String requestId, bool approved})>[];
  final List<({String requestId, Map<String, List<String>> answers})>
  userInputResponses =
      <({String requestId, Map<String, List<String>> answers})>[];
  final List<
    ({
      String requestId,
      CodexAppServerElicitationAction action,
      Object? content,
      Object? metadata,
    })
  >
  elicitationResponses =
      <
        ({
          String requestId,
          CodexAppServerElicitationAction action,
          Object? content,
          Object? metadata,
        })
      >[];
  final List<({String requestId, String message})> rejectedRequests =
      <({String requestId, String message})>[];
  final List<
    ({String requestId, bool success, List<Map<String, Object?>> contentItems})
  >
  dynamicToolResponses =
      <
        ({
          String requestId,
          bool success,
          List<Map<String, Object?>> contentItems,
        })
      >[];
  final Map<String, String> pendingServerRequestMethodsById =
      <String, String>{};
  final Map<String, List<CodexAppServerEvent>>
  resumeThreadReplayEventsByThreadId = <String, List<CodexAppServerEvent>>{};
  final List<CodexAppServerEvent> connectEventsBeforeThrow =
      <CodexAppServerEvent>[];
  Object? connectError;
  Completer<void>? connectGate;
  Object? startSessionError;
  Object? forkThreadError;
  Object? sendUserMessageError;
  Object? steerActiveTurnError;
  Object? readThreadWithTurnsError;
  Object? rollbackThreadError;
  Object? listModelsError;
  String? startSessionModel;
  String? forkThreadId;
  String? startSessionReasoningEffort;
  String? startSessionCwd;
  String? listModelsNextCursor;
  int? listModelsDefaultPageSize;
  final List<CodexAppServerModelListPage> listedModelPages =
      <CodexAppServerModelListPage>[];
  int disconnectCalls = 0;
  String? connectedThreadId;
  Completer<void>? sendUserMessageGate;
  Completer<void>? steerActiveTurnGate;
  Completer<void>? readThreadWithTurnsGate;
  Completer<void>? rollbackThreadGate;
  final Map<String, Completer<void>> readThreadWithTurnsGatesByThreadId =
      <String, Completer<void>>{};
  final Map<String, AgentAdapterThreadSummary> threadsById =
      <String, AgentAdapterThreadSummary>{};
  final Map<String, CodexAppServerThreadHistory> threadHistoriesById =
      <String, CodexAppServerThreadHistory>{};
  final List<CodexAppServerThreadSummary> listedThreads =
      <CodexAppServerThreadSummary>[];
  final List<CodexAppServerModel> listedModels = <CodexAppServerModel>[];

  bool _isConnected = false;
  String? _threadId;
  String? _activeTurnId;

  @override
  Stream<CodexAppServerEvent> get events => _eventsController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  String? get threadId => _threadId;

  @override
  String? get activeTurnId => _activeTurnId;
}
