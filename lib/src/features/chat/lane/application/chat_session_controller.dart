import 'package:pocket_relay/src/agent_adapters/agent_adapter_capabilities.dart';
import 'package:pocket_relay/src/agent_adapters/agent_adapter_registry.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/core/utils/platform_capabilities.dart';
import 'package:pocket_relay/src/core/utils/shell_utils.dart';
import 'package:pocket_relay/src/features/chat/composer/domain/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_conversation_recovery_policy.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_effect_coordinator.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_errors.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_guardrail_errors.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_recovery_coordinator.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_request_coordinator.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_send_coordinator.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/chat_historical_conversation_restorer.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/codex_historical_conversation_normalizer.dart';
import 'package:pocket_relay/src/features/chat/runtime/application/agent_adapter_runtime_event_bridge.dart';
import 'package:pocket_relay/src/features/chat/runtime/application/host_adapter_runtime_event_mapper.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_item_support.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_reducer.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_conversation_recovery_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_historical_conversation_restore_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_client.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_models.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_work_log_terminal_contract.dart';

part 'chat_session_controller_history.dart';
part 'chat_session_controller_init.dart';
part 'chat_session_controller_model_capabilities.dart';
part 'chat_session_controller_recovery.dart';
part 'chat_session_controller_support.dart';
part 'chat_session_controller_thread_metadata.dart';
part 'chat_session_controller_turn_completion.dart';
part 'chat_session_controller_work_log_terminal.dart';

class ChatSessionController extends ChangeNotifier {
  ChatSessionController({
    required this.profileStore,
    AgentAdapterClient? injectedAgentAdapterClient,
    AgentAdapterCapabilities? injectedAgentAdapterCapabilities,
    @Deprecated('Use agentAdapterClient instead.')
    AgentAdapterClient? appServerClient,
    SavedProfile? initialSavedProfile,
    TranscriptReducer reducer = const TranscriptReducer(),
    AgentAdapterRuntimeEventMapper? runtimeEventMapper,
    CodexHistoricalConversationNormalizer historicalConversationNormalizer =
        const CodexHistoricalConversationNormalizer(),
    ChatHistoricalConversationRestorer? historicalConversationRestorer,
    bool? supportsLocalConnectionMode,
  }) : assert(
         injectedAgentAdapterClient != null || appServerClient != null,
         'An agent adapter client is required.',
       ),
       agentAdapterClient = injectedAgentAdapterClient ?? appServerClient!,
       _injectedAgentAdapterCapabilities = injectedAgentAdapterCapabilities,
       _sessionReducer = reducer,
       _runtimeEventMapper =
           runtimeEventMapper ??
           createAgentAdapterRuntimeEventMapper(
             initialSavedProfile?.profile.agentAdapter ??
                 ConnectionProfile.defaults().agentAdapter,
           ),
       _historicalConversationNormalizer = historicalConversationNormalizer,
       _historicalConversationRestorer =
           historicalConversationRestorer ??
           ChatHistoricalConversationRestorer(reducer: reducer),
       _supportsLocalConnectionMode =
           supportsLocalConnectionMode ??
           supportsLocalAgentAdapterConnection() {
    _requestCoordinator = DefaultChatSessionRequestCoordinator(
      context: _ChatSessionRequestCoordinatorContextAdapter(this),
    );
    _effectCoordinator = DefaultChatSessionEffectCoordinator(
      context: _ChatSessionEffectCoordinatorContextAdapter(this),
    );
    _sendCoordinator = DefaultChatSessionSendCoordinator(
      context: _ChatSessionSendCoordinatorContextAdapter(this),
    );
    _recoveryCoordinator = DefaultChatSessionRecoveryCoordinator(
      context: _ChatSessionRecoveryCoordinatorContextAdapter(this),
    );
    final initial = initialSavedProfile;
    if (initial != null) {
      _profile = initial.profile;
      _secrets = initial.secrets;
      _isLoading = false;
    }
    _appServerEventSubscription = agentAdapterClient.events.listen(
      _handleAppServerEvent,
    );
  }

  final CodexProfileStore profileStore;
  final AgentAdapterClient agentAdapterClient;
  @Deprecated('Use agentAdapterClient instead.')
  AgentAdapterClient get appServerClient => agentAdapterClient;

  final TranscriptReducer _sessionReducer;
  final AgentAdapterRuntimeEventMapper _runtimeEventMapper;
  final CodexHistoricalConversationNormalizer _historicalConversationNormalizer;
  final ChatHistoricalConversationRestorer _historicalConversationRestorer;
  final AgentAdapterCapabilities? _injectedAgentAdapterCapabilities;
  final ChatConversationRecoveryPolicy _conversationRecoveryPolicy =
      const ChatConversationRecoveryPolicy();
  final bool _supportsLocalConnectionMode;
  late final ChatSessionRequestCoordinator _requestCoordinator;
  late final ChatSessionEffectCoordinator _effectCoordinator;
  late final ChatSessionSendCoordinator _sendCoordinator;
  late final ChatSessionRecoveryCoordinator _recoveryCoordinator;

  // Send/recovery shared connection identity and persisted credentials.
  final _snackBarMessagesController = StreamController<String>.broadcast();
  final _turnCompletedEventsController =
      StreamController<ChatSessionTurnCompletedEvent>.broadcast();

  ConnectionProfile _profile = ConnectionProfile.defaults();
  ConnectionSecrets _secrets = const ConnectionSecrets();
  TranscriptSessionState _sessionState = TranscriptSessionState.initial();
  ChatConversationRecoveryState? _conversationRecoveryState;
  ChatHistoricalConversationRestoreState? _historicalConversationRestoreState;
  List<AgentAdapterModel>? _modelCatalog;

  // Controller lifecycle owner.
  bool _isLoading = true;
  bool _isDisposed = false;

  // Effect coordinator owner.
  bool _isTrackingSshBootstrapFailures = false;
  bool _sawTrackedSshBootstrapFailure = false;
  bool _sawTrackedUnpinnedHostKeyFailure = false;
  bool _isBufferingRuntimeEvents = false;
  final List<TranscriptRuntimeEvent> _bufferedRuntimeEvents =
      <TranscriptRuntimeEvent>[];

  // Recovery/history owner.
  bool _suppressTrackedThreadReuse = false;
  int _historicalConversationRestoreGeneration = 0;

  // Model/capability hydration owner.
  bool _didAttemptModelCatalogHydration = false;
  StreamSubscription<AgentAdapterEvent>? _appServerEventSubscription;
  Future<void>? _initializationFuture;
  Future<void>? _modelCatalogHydrationFuture;
  final Set<String> _threadMetadataHydrationAttempts = <String>{};

  Stream<String> get snackBarMessages => _snackBarMessagesController.stream;
  Stream<ChatSessionTurnCompletedEvent> get turnCompletedEvents =>
      _turnCompletedEventsController.stream;

  ConnectionProfile get profile => _profile;
  ConnectionSecrets get secrets => _secrets;
  AgentAdapterCapabilities get agentAdapterCapabilities =>
      _injectedAgentAdapterCapabilities ??
      agentAdapterCapabilitiesFor(_profile.agentAdapter);
  TranscriptSessionState get sessionState => _sessionState;
  ChatConversationRecoveryState? get conversationRecoveryState =>
      _conversationRecoveryState;
  ChatHistoricalConversationRestoreState?
  get historicalConversationRestoreState => _historicalConversationRestoreState;
  bool get isLoading => _isLoading;
  bool get suppressesTrackedThreadReuse => _suppressTrackedThreadReuse;
  bool get currentModelSupportsImageInput => _currentModelSupportsImageInput();
  List<TranscriptUiBlock> get transcriptBlocks =>
      _sessionState.transcriptBlocks;

  Future<void> initialize() {
    return _initializationFuture ??= _initializeOnce();
  }

  Future<void> _initializeOnce() {
    return _ChatSessionControllerInit(this)._initializeOnce();
  }

  Future<void> saveObservedHostFingerprint(String blockId) {
    return _sendCoordinator.saveObservedHostFingerprint(blockId);
  }

  Future<bool> sendPrompt(String prompt) {
    return _sendCoordinator.sendPrompt(prompt);
  }

  Future<bool> sendDraft(ChatComposerDraft draft) {
    return _sendCoordinator.sendDraft(draft);
  }

  Future<void> stopActiveTurn() {
    return _sendCoordinator.stopActiveTurn();
  }

  void startFreshConversation() {
    _recoveryCoordinator.startFreshConversation();
  }

  void clearTranscript() {
    _recoveryCoordinator.clearTranscript();
  }

  void openConversationRecoveryAlternateSession() {
    _recoveryCoordinator.openConversationRecoveryAlternateSession();
  }

  void selectTimeline(String threadId) {
    final normalizedThreadId = threadId.trim();
    if (normalizedThreadId.isEmpty ||
        _sessionState.currentThreadId == normalizedThreadId) {
      return;
    }

    final timeline = _sessionState.timelineForThread(normalizedThreadId);
    if (timeline == null) {
      return;
    }

    final nextTimelines = <String, TranscriptTimelineState>{
      for (final entry in _sessionState.timelinesByThreadId.entries)
        entry.key: entry.key == normalizedThreadId
            ? entry.value.copyWith(hasUnreadActivity: false)
            : entry.value,
    };
    _applySessionState(
      _sessionState.copyWith(
        selectedThreadId: normalizedThreadId,
        timelinesByThreadId: nextTimelines,
      ),
    );
  }

  Future<void> selectConversationForResume(String threadId) {
    return _recoveryCoordinator.selectConversationForResume(threadId);
  }

  Future<void> reattachConversation(String threadId) {
    return _recoveryCoordinator.reattachConversation(threadId);
  }

  Future<void> retryHistoricalConversationRestore() {
    return _recoveryCoordinator.retryHistoricalConversationRestore();
  }

  Future<ChatComposerDraft?> continueFromUserMessage(String blockId) {
    return _recoveryCoordinator.continueFromUserMessage(blockId);
  }

  Future<ChatWorkLogTerminalContract> hydrateWorkLogTerminal(
    ChatWorkLogTerminalContract terminal,
  ) {
    return _hydrateChatWorkLogTerminal(this, terminal);
  }

  Future<bool> branchSelectedConversation() {
    return _recoveryCoordinator.branchSelectedConversation();
  }

  Future<void> approveRequest(String requestId) {
    return _requestCoordinator.approveRequest(requestId);
  }

  Future<void> denyRequest(String requestId) {
    return _requestCoordinator.denyRequest(requestId);
  }

  Future<void> submitUserInput(
    String requestId,
    Map<String, List<String>> answers,
  ) {
    return _requestCoordinator.submitUserInput(requestId, answers);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _appServerEventSubscription?.cancel();
    unawaited(agentAdapterClient.disconnect());
    unawaited(_snackBarMessagesController.close());
    unawaited(_turnCompletedEventsController.close());
    super.dispose();
  }

  void _applySessionState(TranscriptSessionState nextState) {
    if (_isDisposed) {
      return;
    }

    _sessionState = nextState;
    notifyListeners();
  }

  TranscriptSshUnpinnedHostKeyBlock? _findUnpinnedHostKeyBlock(String blockId) {
    for (final block in _sessionState.blocks) {
      if (block is TranscriptSshUnpinnedHostKeyBlock && block.id == blockId) {
        return block;
      }
    }
    return null;
  }

  void _handleAppServerEvent(AgentAdapterEvent event) {
    _effectCoordinator.handleAgentAdapterEvent(event);
  }

  bool _isUnsupportedHostRequest(String method) {
    return method == 'account/chatgptAuthTokens/refresh' ||
        method == 'item/tool/call';
  }

  Future<void> _restoreConversationTranscript(String threadId) async {
    await _restoreConversationTranscriptForController(this, threadId);
  }

  Future<TranscriptSessionState?> _performHistoryRestoringThreadTransition({
    required Future<AgentAdapterThreadHistory> Function() operation,
    required PocketUserFacingError userFacingError,
    ChatHistoricalConversationRestoreState? loadingRestoreState,
    ChatHistoricalConversationRestoreState? emptyHistoryRestoreState,
    ChatHistoricalConversationRestoreState? failureRestoreState,
  }) async {
    return _performHistoryRestoringThreadTransitionForController(
      this,
      operation: operation,
      userFacingError: userFacingError,
      loadingRestoreState: loadingRestoreState,
      emptyHistoryRestoreState: emptyHistoryRestoreState,
      failureRestoreState: failureRestoreState,
    );
  }

  Future<bool> _sendPromptWithAppServer(String prompt) async {
    return _sendPromptWithAppServerForController(this, prompt);
  }

  Future<bool> _sendDraftWithAppServer(ChatComposerDraft draft) async {
    return _sendDraftWithAppServerForController(this, draft);
  }

  String? _selectedModelOverride() {
    final model = _profile.model.trim();
    return model.isEmpty ? null : model;
  }

  Future<void> _stopAppServerTurn() async {
    await _stopChatSessionAppServerTurn(this);
  }

  void _applyRuntimeEvent(TranscriptRuntimeEvent event) {
    _effectCoordinator.applyRuntimeEvent(event);
  }

  void _reportAppServerFailure({
    required PocketUserFacingError userFacingError,
    String? runtimeErrorMessage,
    bool suppressRuntimeError = false,
    bool suppressSnackBar = false,
  }) {
    _effectCoordinator.reportAppServerFailure(
      userFacingError: userFacingError,
      runtimeErrorMessage: runtimeErrorMessage,
      suppressRuntimeError: suppressRuntimeError,
      suppressSnackBar: suppressSnackBar,
    );
  }

  void _notifyListenersIfMounted() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  int _beginHistoricalConversationRestore({
    ChatHistoricalConversationRestoreState? loadingState,
  }) {
    final generation = ++_historicalConversationRestoreGeneration;
    if (loadingState != null) {
      _setHistoricalConversationRestoreState(loadingState);
    }
    return generation;
  }

  void _invalidateHistoricalConversationRestore() {
    _historicalConversationRestoreGeneration += 1;
  }

  bool _isCurrentHistoricalConversationRestore(int generation) {
    return _historicalConversationRestoreGeneration == generation;
  }
}

final class _ChatSessionSendCoordinatorContextAdapter
    implements ChatSessionSendCoordinatorContext {
  _ChatSessionSendCoordinatorContextAdapter(this._controller);

  final ChatSessionController _controller;

  @override
  ConnectionProfile get profile => _controller._profile;

  @override
  ConnectionSecrets get secrets => _controller._secrets;

  @override
  TranscriptSessionState get sessionState => _controller._sessionState;

  @override
  ChatConversationRecoveryState? get conversationRecoveryState =>
      _controller._conversationRecoveryState;

  @override
  ChatHistoricalConversationRestoreState?
  get historicalConversationRestoreState =>
      _controller._historicalConversationRestoreState;

  @override
  ChatConversationRecoveryPolicy get conversationRecoveryPolicy =>
      _controller._conversationRecoveryPolicy;

  @override
  AgentAdapterClient get agentAdapterClient => _controller.agentAdapterClient;

  @override
  bool get supportsLocalConnectionMode =>
      _controller._supportsLocalConnectionMode;

  @override
  TranscriptSshUnpinnedHostKeyBlock? findUnpinnedHostKeyBlock(String blockId) {
    return _controller._findUnpinnedHostKeyBlock(blockId);
  }

  @override
  Future<void> persistProfile(ConnectionProfile profile) {
    return _controller.profileStore.save(profile, _controller._secrets);
  }

  @override
  void updateProfile(ConnectionProfile profile) {
    if (_controller._isDisposed) {
      return;
    }
    _controller._profile = profile;
  }

  @override
  void emitUserFacingError(PocketUserFacingError error) {
    _controller._emitUserFacingError(error);
  }

  @override
  void applySessionState(TranscriptSessionState nextState) {
    _controller._applySessionState(nextState);
  }

  @override
  TranscriptSessionState markUnpinnedHostKeySaved(String blockId) {
    return _controller._sessionReducer.markUnpinnedHostKeySaved(
      _controller._sessionState,
      blockId: blockId,
    );
  }

  @override
  TranscriptSessionState addUserMessage({
    required String text,
    ChatComposerDraft? draft,
  }) {
    return _controller._sessionReducer.addUserMessage(
      _controller._sessionState,
      text: text,
      draft: draft,
    );
  }

  @override
  void selectTimeline(String threadId) {
    _controller.selectTimeline(threadId);
  }

  @override
  String? activeConversationThreadId() {
    if (_controller._profile.ephemeralSession) {
      return null;
    }
    return _normalizedThreadId(_controller._sessionState.rootThreadId);
  }

  @override
  String? trackedThreadReuseCandidate() {
    if (_controller._profile.ephemeralSession ||
        _controller._suppressTrackedThreadReuse ||
        _controller._sessionState.hasMultipleTimelines) {
      return null;
    }

    return _normalizedThreadId(_controller.agentAdapterClient.threadId);
  }

  @override
  void setConversationRecovery(ChatConversationRecoveryState nextState) {
    final currentState = _controller._conversationRecoveryState;
    if (currentState?.reason == nextState.reason &&
        currentState?.alternateThreadId == nextState.alternateThreadId &&
        currentState?.expectedThreadId == nextState.expectedThreadId &&
        currentState?.actualThreadId == nextState.actualThreadId) {
      return;
    }

    _controller._conversationRecoveryState = nextState;
    _controller._notifyListenersIfMounted();
  }

  @override
  bool canSendAdditionalInputToCurrentTurn() {
    if (_activeTurnIdForSteering() == null ||
        _controller.agentAdapterCapabilities.supportsLiveTurnSteering) {
      return true;
    }

    _controller._emitUserFacingError(
      ChatSessionGuardrailErrors.liveTurnSteeringUnsupported(),
    );
    return false;
  }

  @override
  Future<bool> ensureImageInputsSupportedForDraft(ChatComposerDraft draft) {
    return _controller._ensureImageInputsSupportedForDraft(draft);
  }

  @override
  Future<bool> sendPromptWithAppServer(String prompt) {
    return _controller._sendPromptWithAppServer(prompt);
  }

  @override
  Future<bool> sendDraftWithAppServer(ChatComposerDraft draft) {
    return _controller._sendDraftWithAppServer(draft);
  }

  @override
  Future<void> stopAppServerTurn() {
    return _controller._stopAppServerTurn();
  }

  String? _normalizedThreadId(String? value) {
    final normalizedValue = value?.trim();
    if (normalizedValue == null || normalizedValue.isEmpty) {
      return null;
    }
    return normalizedValue;
  }

  String? _activeTurnIdForSteering() {
    final transportTurnId = _normalizedTurnId(
      _controller.agentAdapterClient.activeTurnId,
    );
    if (transportTurnId != null) {
      return transportTurnId;
    }

    if (_controller.agentAdapterClient.isConnected) {
      return null;
    }

    return _normalizedTurnId(_controller._sessionState.activeTurn?.turnId);
  }

  String? _normalizedTurnId(String? value) {
    final normalizedValue = value?.trim();
    if (normalizedValue == null || normalizedValue.isEmpty) {
      return null;
    }
    return normalizedValue;
  }
}

final class _ChatSessionRecoveryCoordinatorContextAdapter
    implements ChatSessionRecoveryCoordinatorContext {
  _ChatSessionRecoveryCoordinatorContextAdapter(this._controller);

  final ChatSessionController _controller;

  @override
  TranscriptSessionState get sessionState => _controller._sessionState;

  @override
  ChatConversationRecoveryState? get conversationRecoveryState =>
      _controller._conversationRecoveryState;

  @override
  ChatHistoricalConversationRestoreState?
  get historicalConversationRestoreState =>
      _controller._historicalConversationRestoreState;

  @override
  AgentAdapterClient get agentAdapterClient => _controller.agentAdapterClient;

  @override
  void emitUserFacingError(PocketUserFacingError error) {
    _controller._emitUserFacingError(error);
  }

  @override
  void applySessionState(TranscriptSessionState nextState) {
    _controller._applySessionState(nextState);
  }

  @override
  TranscriptSessionState startFreshThread({String? message}) {
    return _controller._sessionReducer.startFreshThread(
      _controller._sessionState,
      message: message,
    );
  }

  @override
  TranscriptSessionState clearTranscriptState() {
    return _controller._sessionReducer.clearTranscript(
      _controller._sessionState,
    );
  }

  @override
  void invalidateHistoricalConversationRestore() {
    _controller._invalidateHistoricalConversationRestore();
  }

  @override
  void clearConversationRecovery() {
    if (_controller._conversationRecoveryState == null) {
      return;
    }
    _controller._conversationRecoveryState = null;
    _controller._notifyListenersIfMounted();
  }

  @override
  void clearHistoricalConversationRestoreState() {
    if (_controller._historicalConversationRestoreState == null) {
      return;
    }
    _controller._historicalConversationRestoreState = null;
    _controller._notifyListenersIfMounted();
  }

  @override
  void setSuppressTrackedThreadReuse(bool value) {
    _controller._suppressTrackedThreadReuse = value;
  }

  @override
  String? normalizeThreadId(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  @override
  String? activeConversationThreadId() {
    if (_controller._profile.ephemeralSession) {
      return null;
    }
    return _normalizeNullable(_controller._sessionState.rootThreadId);
  }

  @override
  String? selectedConversationThreadId() {
    if (_controller._profile.ephemeralSession) {
      return null;
    }
    return _normalizeNullable(
      _controller._sessionState.currentThreadId ??
          _controller._sessionState.rootThreadId,
    );
  }

  @override
  bool hasVisibleConversationState([TranscriptSessionState? state]) {
    final effectiveState = state ?? _controller._sessionState;
    return effectiveState.activeTurn != null ||
        effectiveState.pendingApprovalRequests.isNotEmpty ||
        effectiveState.pendingUserInputRequests.isNotEmpty ||
        effectiveState.transcriptBlocks.isNotEmpty;
  }

  @override
  Future<void> restoreConversationTranscript(String threadId) {
    return _controller._restoreConversationTranscript(threadId);
  }

  @override
  Future<void> resumeConversationThread(String threadId) {
    return _controller._resumeConversationThread(threadId);
  }

  @override
  Future<void> reattachConversationWithHistoryBaseline(String threadId) {
    return _controller._reattachConversationWithHistoryBaseline(threadId);
  }

  @override
  Future<TranscriptSessionState?> performHistoryRestoringThreadTransition({
    required Future<AgentAdapterThreadHistory> Function() operation,
    required PocketUserFacingError userFacingError,
    ChatHistoricalConversationRestoreState? loadingRestoreState,
    ChatHistoricalConversationRestoreState? emptyHistoryRestoreState,
    ChatHistoricalConversationRestoreState? failureRestoreState,
  }) {
    return _controller._performHistoryRestoringThreadTransition(
      operation: operation,
      userFacingError: userFacingError,
      loadingRestoreState: loadingRestoreState,
      emptyHistoryRestoreState: emptyHistoryRestoreState,
      failureRestoreState: failureRestoreState,
    );
  }

  String? _normalizeNullable(String? value) {
    final normalizedValue = value?.trim();
    if (normalizedValue == null || normalizedValue.isEmpty) {
      return null;
    }
    return normalizedValue;
  }
}

final class _ChatSessionRequestCoordinatorContextAdapter
    implements ChatSessionRequestCoordinatorContext {
  _ChatSessionRequestCoordinatorContextAdapter(this._controller);

  final ChatSessionController _controller;

  @override
  AgentAdapterClient get agentAdapterClient => _controller.agentAdapterClient;

  @override
  TranscriptSessionPendingRequest? findPendingApprovalRequest(
    String requestId,
  ) {
    return _controller._findPendingApprovalRequest(requestId);
  }

  @override
  TranscriptSessionPendingUserInputRequest? findPendingUserInputRequest(
    String requestId,
  ) {
    return _controller._findPendingUserInputRequest(requestId);
  }

  @override
  void emitUserFacingError(PocketUserFacingError error) {
    _controller._emitUserFacingError(error);
  }

  @override
  void reportAppServerFailure({
    required PocketUserFacingError userFacingError,
    String? runtimeErrorMessage,
    bool suppressRuntimeError = false,
    bool suppressSnackBar = false,
  }) {
    _controller._reportAppServerFailure(
      userFacingError: userFacingError,
      runtimeErrorMessage: runtimeErrorMessage,
      suppressRuntimeError: suppressRuntimeError,
      suppressSnackBar: suppressSnackBar,
    );
  }

  @override
  void applyRuntimeEvent(TranscriptRuntimeEvent event) {
    _controller._applyRuntimeEvent(event);
  }
}

final class _ChatSessionEffectCoordinatorContextAdapter
    implements ChatSessionEffectCoordinatorContext {
  _ChatSessionEffectCoordinatorContextAdapter(this._controller);

  final ChatSessionController _controller;

  @override
  AgentAdapterRuntimeEventMapper get runtimeEventMapper =>
      _controller._runtimeEventMapper;

  @override
  TranscriptReducer get sessionReducer => _controller._sessionReducer;

  @override
  TranscriptSessionState get sessionState => _controller._sessionState;

  @override
  bool get isTrackingSshBootstrapFailures =>
      _controller._isTrackingSshBootstrapFailures;

  @override
  set isTrackingSshBootstrapFailures(bool value) {
    _controller._isTrackingSshBootstrapFailures = value;
  }

  @override
  bool get sawTrackedSshBootstrapFailure =>
      _controller._sawTrackedSshBootstrapFailure;

  @override
  set sawTrackedSshBootstrapFailure(bool value) {
    _controller._sawTrackedSshBootstrapFailure = value;
  }

  @override
  bool get sawTrackedUnpinnedHostKeyFailure =>
      _controller._sawTrackedUnpinnedHostKeyFailure;

  @override
  set sawTrackedUnpinnedHostKeyFailure(bool value) {
    _controller._sawTrackedUnpinnedHostKeyFailure = value;
  }

  @override
  bool get isBufferingRuntimeEvents => _controller._isBufferingRuntimeEvents;

  @override
  void resetModelCatalogHydration() {
    _controller._resetModelCatalogHydration();
  }

  @override
  bool isUnsupportedHostRequest(String method) {
    return _controller._isUnsupportedHostRequest(method);
  }

  @override
  Future<void> handleUnsupportedHostRequest(AgentAdapterRequestEvent event) {
    return _controller._requestCoordinator.handleUnsupportedHostRequest(event);
  }

  @override
  bool isSshBootstrapFailureRuntimeEvent(TranscriptRuntimeEvent event) {
    return _controller._isSshBootstrapFailureRuntimeEvent(event);
  }

  @override
  void bufferRuntimeEvent(TranscriptRuntimeEvent event) {
    _controller._bufferedRuntimeEvents.add(event);
  }

  @override
  void applySessionState(TranscriptSessionState nextState) {
    _controller._applySessionState(nextState);
  }

  @override
  void emitTurnCompleted({required String turnId, String? threadId}) {
    _controller._turnCompletedEventsController.add(
      ChatSessionTurnCompletedEvent(turnId: turnId, threadId: threadId),
    );
  }

  @override
  void hydrateThreadMetadataIfNeeded(
    TranscriptRuntimeThreadStartedEvent event,
  ) {
    unawaited(_hydrateChatSessionThreadMetadataIfNeeded(_controller, event));
  }

  @override
  void emitSnackBar(String message) {
    _controller._emitSnackBar(message);
  }
}
