import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/composer/domain/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_conversation_recovery_policy.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_effect_coordinator.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_recovery_coordinator.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_request_coordinator.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_send_coordinator.dart';
import 'package:pocket_relay/src/features/chat/runtime/application/agent_adapter_runtime_event_mapper.dart';
import 'package:pocket_relay/src/features/chat/runtime/domain/agent_adapter_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_reducer.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_conversation_recovery_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_historical_conversation_restore_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_client.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_models.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/testing/fake_agent_adapter_client.dart';

void main() {
  group('DefaultChatSessionSendCoordinator', () {
    test(
      'adds a normalized local user message before delegating prompt send',
      () async {
        final context = _FakeSendCoordinatorContext();
        final coordinator = DefaultChatSessionSendCoordinator(context: context);

        final sent = await coordinator.sendPrompt('  Hello coordinator  ');

        expect(sent, isTrue);
        expect(context.sentPrompts, <String>['Hello coordinator']);
        final userMessage =
            context.sessionState.transcriptBlocks.single
                as TranscriptUserMessageBlock;
        expect(userMessage.text, 'Hello coordinator');
        expect(context.appliedStates, hasLength(1));
      },
    );
  });

  group('DefaultChatSessionRecoveryCoordinator', () {
    test(
      'trims the selected thread id before restoring transcript history',
      () async {
        final context = _FakeRecoveryCoordinatorContext();
        final coordinator = DefaultChatSessionRecoveryCoordinator(
          context: context,
        );

        await coordinator.selectConversationForResume('  thread_saved  ');

        expect(context.suppressTrackedThreadReuse, isFalse);
        expect(context.restoreConversationTranscriptCalls, <String>[
          'thread_saved',
        ]);
      },
    );

    test(
      'promotes the alternate session to primary and clears recovery state',
      () {
        final context = _FakeRecoveryCoordinatorContext(
          sessionState: TranscriptSessionState(
            rootThreadId: 'thread_primary',
            selectedThreadId: 'thread_primary',
            timelinesByThreadId: const <String, TranscriptTimelineState>{
              'thread_primary': TranscriptTimelineState(
                threadId: 'thread_primary',
              ),
              'thread_alt': TranscriptTimelineState(threadId: 'thread_alt'),
            },
            threadRegistry: const <String, TranscriptThreadRegistryEntry>{
              'thread_primary': TranscriptThreadRegistryEntry(
                threadId: 'thread_primary',
                displayOrder: 0,
                isPrimary: true,
              ),
              'thread_alt': TranscriptThreadRegistryEntry(
                threadId: 'thread_alt',
                displayOrder: 1,
              ),
            },
          ),
          conversationRecoveryState: const ChatConversationRecoveryState(
            reason: ChatConversationRecoveryReason.detachedTranscript,
            alternateThreadId: 'thread_alt',
          ),
          historicalConversationRestoreState:
              const ChatHistoricalConversationRestoreState(
                threadId: 'thread_primary',
                phase: ChatHistoricalConversationRestorePhase.loading,
              ),
        );
        final coordinator = DefaultChatSessionRecoveryCoordinator(
          context: context,
        );

        coordinator.openConversationRecoveryAlternateSession();

        expect(context.invalidatedHistoricalConversationRestore, isTrue);
        expect(context.suppressTrackedThreadReuse, isFalse);
        expect(context.conversationRecoveryState, isNull);
        expect(context.historicalConversationRestoreState, isNull);
        expect(context.sessionState.rootThreadId, 'thread_alt');
        expect(context.sessionState.selectedThreadId, 'thread_alt');
        expect(
          context.sessionState.threadRegistry['thread_alt']?.isPrimary,
          isTrue,
        );
        expect(
          context.sessionState.threadRegistry['thread_primary']?.isPrimary,
          isFalse,
        );
      },
    );
  });

  group('DefaultChatSessionRequestCoordinator', () {
    test(
      'rejects unsupported dynamic tool requests without a controller instance',
      () async {
        final client = FakeAgentAdapterClient()
          ..pendingServerRequestMethodsById['req_tool'] = 'item/tool/call';
        addTearDown(client.close);
        final context = _FakeRequestCoordinatorContext(
          agentAdapterClient: client,
        );
        final coordinator = DefaultChatSessionRequestCoordinator(
          context: context,
        );

        await coordinator.handleUnsupportedHostRequest(
          const AgentAdapterRequestEvent(
            requestId: 'req_tool',
            method: 'item/tool/call',
            params: <String, Object?>{
              'threadId': 'thread_123',
              'turnId': 'turn_1',
              'itemId': 'item_1',
              'tool': 'grep',
            },
          ),
        );

        final statusEvent =
            context.runtimeEvents.single as TranscriptRuntimeStatusEvent;
        expect(statusEvent.title, 'Dynamic tool unsupported');
        expect(
          statusEvent.message,
          contains('experimental host-side tool "grep"'),
        );
        expect(client.dynamicToolResponses, hasLength(1));
        final response = client.dynamicToolResponses.single;
        expect(response.requestId, 'req_tool');
        expect(response.success, isFalse);
        expect(response.contentItems.single['type'], 'inputText');
        expect(
          response.contentItems.single['text'],
          contains('experimental host-side tool "grep"'),
        );
      },
    );
  });

  group('DefaultChatSessionEffectCoordinator', () {
    test(
      'routes unsupported host requests through the request coordinator seam',
      () async {
        final mapper = _FakeRuntimeEventMapper();
        final context = _FakeEffectCoordinatorContext(
          runtimeEventMapper: mapper,
          unsupportedMethods: <String>{'item/tool/call'},
        );
        final coordinator = DefaultChatSessionEffectCoordinator(
          context: context,
        );
        const event = AgentAdapterRequestEvent(
          requestId: 'req_tool',
          method: 'item/tool/call',
          params: <String, Object?>{'tool': 'grep'},
        );

        coordinator.handleAgentAdapterEvent(event);
        await Future<void>.delayed(Duration.zero);

        expect(context.unsupportedHostRequestEvents, <AgentAdapterRequestEvent>[
          event,
        ]);
        expect(mapper.mapCalls, 0);
        expect(context.appliedStates, isEmpty);
      },
    );

    test(
      'buffers transcript runtime events while history restoration owns projection',
      () {
        final reducer = _RecordingTranscriptReducer();
        final context = _FakeEffectCoordinatorContext(
          sessionReducer: reducer,
          isBufferingRuntimeEvents: true,
        );
        final coordinator = DefaultChatSessionEffectCoordinator(
          context: context,
        );
        final event = TranscriptRuntimeWarningEvent(
          createdAt: DateTime(2026),
          rawMethod: 'warning/test',
          summary: 'Buffered warning',
        );

        coordinator.applyRuntimeEvent(event);

        expect(context.bufferedEvents, <TranscriptRuntimeEvent>[event]);
        expect(reducer.reducedEvents, isEmpty);
        expect(context.appliedStates, isEmpty);
      },
    );
  });
}

ConnectionProfile _configuredProfile() {
  return ConnectionProfile.defaults().copyWith(
    host: 'example.com',
    username: 'vince',
    workspaceDir: '/workspace',
  );
}

final class _FakeSendCoordinatorContext
    implements ChatSessionSendCoordinatorContext {
  _FakeSendCoordinatorContext({
    ConnectionProfile? profile,
    AgentAdapterClient? agentAdapterClient,
    this.secrets = const ConnectionSecrets(password: 'secret'),
    TranscriptSessionState? sessionState,
    this.conversationRecoveryState,
    this.historicalConversationRestoreState,
    this.supportsLocalConnectionMode = true,
    this.canSendAdditionalInput = true,
    this.sendPromptResult = true,
    this.sendDraftResult = true,
    this.imageInputsSupported = true,
  }) : profile = profile ?? _configuredProfile(),
       agentAdapterClient = agentAdapterClient ?? FakeAgentAdapterClient(),
       sessionState =
           sessionState ??
           TranscriptSessionState.transcript(
             connectionStatus: TranscriptRuntimeSessionState.ready,
           );

  final TranscriptReducer _reducer = const TranscriptReducer();
  @override
  ConnectionProfile profile;
  @override
  final AgentAdapterClient agentAdapterClient;
  @override
  final ConnectionSecrets secrets;
  @override
  TranscriptSessionState sessionState;
  @override
  ChatConversationRecoveryState? conversationRecoveryState;
  @override
  ChatHistoricalConversationRestoreState? historicalConversationRestoreState;
  @override
  final bool supportsLocalConnectionMode;
  final bool canSendAdditionalInput;
  final bool sendPromptResult;
  final bool sendDraftResult;
  final bool imageInputsSupported;

  final List<String> sentPrompts = <String>[];
  final List<ChatComposerDraft> sentDrafts = <ChatComposerDraft>[];
  final List<TranscriptSessionState> appliedStates = <TranscriptSessionState>[];
  final List<PocketUserFacingError> emittedErrors = <PocketUserFacingError>[];

  @override
  ChatConversationRecoveryPolicy get conversationRecoveryPolicy =>
      const ChatConversationRecoveryPolicy();

  @override
  TranscriptSshUnpinnedHostKeyBlock? findUnpinnedHostKeyBlock(String blockId) =>
      null;

  @override
  Future<void> persistProfile(ConnectionProfile profile) async {
    this.profile = profile;
  }

  @override
  void updateProfile(ConnectionProfile profile) {
    this.profile = profile;
  }

  @override
  void emitUserFacingError(PocketUserFacingError error) {
    emittedErrors.add(error);
  }

  @override
  void applySessionState(TranscriptSessionState nextState) {
    sessionState = nextState;
    appliedStates.add(nextState);
  }

  @override
  TranscriptSessionState markUnpinnedHostKeySaved(String blockId) {
    return _reducer.markUnpinnedHostKeySaved(sessionState, blockId: blockId);
  }

  @override
  TranscriptSessionState addUserMessage({
    required String text,
    ChatComposerDraft? draft,
  }) {
    return _reducer.addUserMessage(sessionState, text: text, draft: draft);
  }

  @override
  void selectTimeline(String threadId) {
    sessionState = sessionState.copyWith(selectedThreadId: threadId);
  }

  @override
  String? activeConversationThreadId() => null;

  @override
  String? trackedThreadReuseCandidate() => null;

  @override
  void setConversationRecovery(ChatConversationRecoveryState nextState) {
    conversationRecoveryState = nextState;
  }

  @override
  bool canSendAdditionalInputToCurrentTurn() => canSendAdditionalInput;

  @override
  Future<bool> ensureImageInputsSupportedForDraft(
    ChatComposerDraft draft,
  ) async {
    return imageInputsSupported;
  }

  @override
  Future<bool> sendPromptWithAppServer(String prompt) async {
    sentPrompts.add(prompt);
    return sendPromptResult;
  }

  @override
  Future<bool> sendDraftWithAppServer(ChatComposerDraft draft) async {
    sentDrafts.add(draft);
    return sendDraftResult;
  }

  @override
  Future<void> stopAppServerTurn() async {}
}

final class _FakeRecoveryCoordinatorContext
    implements ChatSessionRecoveryCoordinatorContext {
  _FakeRecoveryCoordinatorContext({
    TranscriptSessionState? sessionState,
    this.conversationRecoveryState,
    this.historicalConversationRestoreState,
    AgentAdapterClient? agentAdapterClient,
  }) : sessionState = sessionState ?? TranscriptSessionState.initial(),
       agentAdapterClient = agentAdapterClient ?? FakeAgentAdapterClient();

  final TranscriptReducer _reducer = const TranscriptReducer();

  @override
  TranscriptSessionState sessionState;
  @override
  ChatConversationRecoveryState? conversationRecoveryState;
  @override
  ChatHistoricalConversationRestoreState? historicalConversationRestoreState;
  @override
  final AgentAdapterClient agentAdapterClient;

  final List<PocketUserFacingError> emittedErrors = <PocketUserFacingError>[];
  final List<String> restoreConversationTranscriptCalls = <String>[];
  bool invalidatedHistoricalConversationRestore = false;
  bool suppressTrackedThreadReuse = true;

  @override
  void emitUserFacingError(PocketUserFacingError error) {
    emittedErrors.add(error);
  }

  @override
  void applySessionState(TranscriptSessionState nextState) {
    sessionState = nextState;
  }

  @override
  TranscriptSessionState startFreshThread({String? message}) {
    return _reducer.startFreshThread(sessionState, message: message);
  }

  @override
  TranscriptSessionState clearTranscriptState() {
    return _reducer.clearTranscript(sessionState);
  }

  @override
  void invalidateHistoricalConversationRestore() {
    invalidatedHistoricalConversationRestore = true;
  }

  @override
  void clearConversationRecovery() {
    conversationRecoveryState = null;
  }

  @override
  void clearHistoricalConversationRestoreState() {
    historicalConversationRestoreState = null;
  }

  @override
  void setSuppressTrackedThreadReuse(bool value) {
    suppressTrackedThreadReuse = value;
  }

  @override
  String? normalizeThreadId(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  @override
  String? activeConversationThreadId() => sessionState.rootThreadId;

  @override
  String? selectedConversationThreadId() => sessionState.selectedThreadId;

  @override
  bool hasVisibleConversationState([TranscriptSessionState? state]) {
    return (state ?? sessionState).transcriptBlocks.isNotEmpty;
  }

  @override
  Future<void> restoreConversationTranscript(String threadId) async {
    restoreConversationTranscriptCalls.add(threadId);
  }

  @override
  Future<void> resumeConversationThread(String threadId) async {}

  @override
  Future<void> reattachConversationWithHistoryBaseline(String threadId) async {}

  @override
  Future<TranscriptSessionState?> performHistoryRestoringThreadTransition({
    required Future<AgentAdapterThreadHistory> Function() operation,
    required PocketUserFacingError userFacingError,
    ChatHistoricalConversationRestoreState? loadingRestoreState,
    ChatHistoricalConversationRestoreState? emptyHistoryRestoreState,
    ChatHistoricalConversationRestoreState? failureRestoreState,
  }) async {
    return sessionState;
  }
}

final class _FakeRequestCoordinatorContext
    implements ChatSessionRequestCoordinatorContext {
  _FakeRequestCoordinatorContext({required this.agentAdapterClient});

  @override
  final AgentAdapterClient agentAdapterClient;

  final List<TranscriptRuntimeEvent> runtimeEvents = <TranscriptRuntimeEvent>[];
  final List<PocketUserFacingError> emittedErrors = <PocketUserFacingError>[];
  final List<
    ({
      PocketUserFacingError userFacingError,
      String? runtimeErrorMessage,
      bool suppressRuntimeError,
      bool suppressSnackBar,
    })
  >
  reportedFailures = [];

  @override
  TranscriptSessionPendingRequest? findPendingApprovalRequest(
    String requestId,
  ) {
    return null;
  }

  @override
  TranscriptSessionPendingUserInputRequest? findPendingUserInputRequest(
    String requestId,
  ) {
    return null;
  }

  @override
  void emitUserFacingError(PocketUserFacingError error) {
    emittedErrors.add(error);
  }

  @override
  void reportAppServerFailure({
    required PocketUserFacingError userFacingError,
    String? runtimeErrorMessage,
    bool suppressRuntimeError = false,
    bool suppressSnackBar = false,
  }) {
    reportedFailures.add((
      userFacingError: userFacingError,
      runtimeErrorMessage: runtimeErrorMessage,
      suppressRuntimeError: suppressRuntimeError,
      suppressSnackBar: suppressSnackBar,
    ));
  }

  @override
  void applyRuntimeEvent(TranscriptRuntimeEvent event) {
    runtimeEvents.add(event);
  }
}

final class _FakeEffectCoordinatorContext
    implements ChatSessionEffectCoordinatorContext {
  _FakeEffectCoordinatorContext({
    AgentAdapterRuntimeEventMapper? runtimeEventMapper,
    TranscriptReducer? sessionReducer,
    TranscriptSessionState? sessionState,
    this.isBufferingRuntimeEvents = false,
    Set<String>? unsupportedMethods,
  }) : runtimeEventMapper = runtimeEventMapper ?? _FakeRuntimeEventMapper(),
       sessionReducer = sessionReducer ?? const TranscriptReducer(),
       sessionState = sessionState ?? TranscriptSessionState.initial(),
       unsupportedMethods = unsupportedMethods ?? const <String>{};

  @override
  final AgentAdapterRuntimeEventMapper runtimeEventMapper;
  @override
  final TranscriptReducer sessionReducer;
  @override
  TranscriptSessionState sessionState;
  @override
  bool isTrackingSshBootstrapFailures = false;
  @override
  bool sawTrackedSshBootstrapFailure = false;
  @override
  bool sawTrackedUnpinnedHostKeyFailure = false;
  @override
  final bool isBufferingRuntimeEvents;

  final Set<String> unsupportedMethods;
  final List<TranscriptRuntimeEvent> bufferedEvents =
      <TranscriptRuntimeEvent>[];
  final List<TranscriptSessionState> appliedStates = <TranscriptSessionState>[];
  final List<AgentAdapterRequestEvent> unsupportedHostRequestEvents =
      <AgentAdapterRequestEvent>[];
  final List<String> emittedSnackBars = <String>[];
  final List<TranscriptRuntimeThreadStartedEvent> hydratedThreadEvents =
      <TranscriptRuntimeThreadStartedEvent>[];
  final List<({String turnId, String? threadId})> completedTurns =
      <({String turnId, String? threadId})>[];
  int resetModelCatalogHydrationCalls = 0;

  @override
  void resetModelCatalogHydration() {
    resetModelCatalogHydrationCalls += 1;
  }

  @override
  bool isUnsupportedHostRequest(String method) {
    return unsupportedMethods.contains(method);
  }

  @override
  Future<void> handleUnsupportedHostRequest(
    AgentAdapterRequestEvent event,
  ) async {
    unsupportedHostRequestEvents.add(event);
  }

  @override
  bool isSshBootstrapFailureRuntimeEvent(TranscriptRuntimeEvent event) => false;

  @override
  void bufferRuntimeEvent(TranscriptRuntimeEvent event) {
    bufferedEvents.add(event);
  }

  @override
  void applySessionState(TranscriptSessionState nextState) {
    sessionState = nextState;
    appliedStates.add(nextState);
  }

  @override
  void emitTurnCompleted({required String turnId, String? threadId}) {
    completedTurns.add((turnId: turnId, threadId: threadId));
  }

  @override
  void hydrateThreadMetadataIfNeeded(
    TranscriptRuntimeThreadStartedEvent event,
  ) {
    hydratedThreadEvents.add(event);
  }

  @override
  void emitSnackBar(String message) {
    emittedSnackBars.add(message);
  }
}

final class _FakeRuntimeEventMapper implements AgentAdapterRuntimeEventMapper {
  _FakeRuntimeEventMapper({
    this.mappedEvents = const <AgentAdapterRuntimeEvent>[],
  });

  final List<AgentAdapterRuntimeEvent> mappedEvents;
  int mapCalls = 0;

  @override
  List<AgentAdapterRuntimeEvent> mapEvent(AgentAdapterEvent event) {
    mapCalls += 1;
    return mappedEvents;
  }
}

final class _RecordingTranscriptReducer extends TranscriptReducer {
  final List<TranscriptRuntimeEvent> reducedEvents = <TranscriptRuntimeEvent>[];

  @override
  TranscriptSessionState reduceRuntimeEvent(
    TranscriptSessionState state,
    TranscriptRuntimeEvent event,
  ) {
    reducedEvents.add(event);
    return state;
  }
}
