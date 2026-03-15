import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/features/chat/application/chat_session_controller.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_composer_draft_host.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_overlay_delegate.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_region_policy.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_effect.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_effect_mapper.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_presenter.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_follow_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_follow_host.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/flutter_chat_screen_renderer.dart';

class ChatRootAdapter extends StatefulWidget {
  const ChatRootAdapter({
    super.key,
    required this.profileStore,
    required this.appServerClient,
    this.initialSavedProfile,
    this.regionPolicy = const ChatRootRegionPolicy.allFlutter(),
    this.overlayDelegate = const FlutterChatRootOverlayDelegate(),
  });

  final CodexProfileStore profileStore;
  final CodexAppServerClient appServerClient;
  final SavedProfile? initialSavedProfile;
  final ChatRootRegionPolicy regionPolicy;
  final ChatRootOverlayDelegate overlayDelegate;

  @override
  State<ChatRootAdapter> createState() => _ChatRootAdapterState();
}

class _ChatRootAdapterState extends State<ChatRootAdapter> {
  final _composerDraftHost = ChatComposerDraftHost();
  final _transcriptFollowHost = ChatTranscriptFollowHost();
  final _effectMapper = const ChatScreenEffectMapper();
  final _screenPresenter = const ChatScreenPresenter();
  late ChatSessionController _sessionController;
  StreamSubscription<ChatScreenEffect>? _screenEffectSubscription;

  @override
  void initState() {
    super.initState();
    _sessionController = _buildSessionController();
    _bindScreenEffects();
    unawaited(_sessionController.initialize());
  }

  @override
  void didUpdateWidget(covariant ChatRootAdapter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileStore == widget.profileStore &&
        oldWidget.appServerClient == widget.appServerClient &&
        oldWidget.initialSavedProfile == widget.initialSavedProfile) {
      return;
    }

    _screenEffectSubscription?.cancel();
    _sessionController.dispose();
    _sessionController = _buildSessionController();
    _bindScreenEffects();
    unawaited(_sessionController.initialize());
  }

  @override
  void dispose() {
    _screenEffectSubscription?.cancel();
    _sessionController.dispose();
    _transcriptFollowHost.dispose();
    _composerDraftHost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _sessionController,
        _composerDraftHost,
        _transcriptFollowHost,
      ]),
      builder: (context, _) {
        final screen = _buildScreenContract();
        return FlutterChatScreenRenderer(
          screen: screen,
          appChrome: _buildAppChrome(screen),
          transcriptRegion: _buildTranscriptRegion(screen),
          composerRegion: _buildComposerRegion(screen),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppChrome(ChatScreenContract screen) {
    return switch (widget.regionPolicy.rendererFor(ChatRootRegion.appChrome)) {
      ChatRootRegionRenderer.flutter => FlutterChatAppChrome(
        screen: screen,
        onScreenAction: (action) => _handleScreenAction(action, screen),
      ),
    };
  }

  Widget _buildTranscriptRegion(ChatScreenContract screen) {
    return switch (widget.regionPolicy.rendererFor(ChatRootRegion.transcript)) {
      ChatRootRegionRenderer.flutter => FlutterChatTranscriptRegion(
        screen: screen,
        surfaceChangeToken: _sessionController.sessionState,
        onScreenAction: (action) => _handleScreenAction(action, screen),
        onAutoFollowEligibilityChanged: (isNearBottom) {
          _transcriptFollowHost.updateAutoFollowEligibility(
            isNearBottom: isNearBottom,
          );
        },
        onApproveRequest: _sessionController.approveRequest,
        onDenyRequest: _sessionController.denyRequest,
        onOpenChangedFileDiff: _requestChangedFileDiff,
        onSubmitUserInput: _sessionController.submitUserInput,
      ),
    };
  }

  Widget _buildComposerRegion(ChatScreenContract screen) {
    return switch (widget.regionPolicy.rendererFor(ChatRootRegion.composer)) {
      ChatRootRegionRenderer.flutter => FlutterChatComposerRegion(
        composer: screen.composer,
        onComposerDraftChanged: _composerDraftHost.updateText,
        onSendPrompt: _sendPrompt,
        onStopActiveTurn: _stopActiveTurn,
      ),
    };
  }

  ChatSessionController _buildSessionController() {
    return ChatSessionController(
      profileStore: widget.profileStore,
      appServerClient: widget.appServerClient,
      initialSavedProfile: widget.initialSavedProfile,
    );
  }

  void _bindScreenEffects() {
    _screenEffectSubscription = _sessionController.snackBarMessages
        .map(_effectMapper.mapSnackBarMessage)
        .listen(_handleScreenEffect);
  }

  ChatScreenContract _buildScreenContract() {
    return _screenPresenter.present(
      isLoading: _sessionController.isLoading,
      profile: _sessionController.profile,
      secrets: _sessionController.secrets,
      sessionState: _sessionController.sessionState,
      composerDraft: _composerDraftHost.draft,
      transcriptFollow: _transcriptFollowHost.contract,
    );
  }

  Future<void> _openConnectionSettings(
    ChatConnectionSettingsLaunchContract connectionSettings,
  ) async {
    if (!mounted) {
      return;
    }

    final result = switch (widget.regionPolicy.rendererFor(
      ChatRootRegion.settingsOverlay,
    )) {
      ChatRootRegionRenderer.flutter =>
        await widget.overlayDelegate.openConnectionSettings(
          context: context,
          connectionSettings: connectionSettings,
        ),
    };

    if (result == null) {
      return;
    }

    final connectionChanged =
        result.profile != _sessionController.profile ||
        result.secrets != _sessionController.secrets;

    if (!connectionChanged) {
      return;
    }

    await _sessionController.applyConnectionSettings(
      profile: result.profile,
      secrets: result.secrets,
    );
  }

  Future<void> _openChangedFileDiff(ChatChangedFileDiffContract diff) async {
    if (!mounted) {
      return;
    }

    await widget.overlayDelegate.openChangedFileDiff(
      context: context,
      diff: diff,
    );
  }

  void _requestChangedFileDiff(ChatChangedFileDiffContract diff) {
    _handleScreenEffect(ChatOpenChangedFileDiffEffect(payload: diff));
  }

  void _handleScreenAction(
    ChatScreenActionId action,
    ChatScreenContract screen,
  ) {
    final effect = _effectMapper.mapAction(action: action, screen: screen);
    if (effect != null) {
      _handleScreenEffect(effect);
      return;
    }

    switch (action) {
      case ChatScreenActionId.newThread:
        _startFreshConversation();
      case ChatScreenActionId.clearTranscript:
        _clearTranscript();
      case ChatScreenActionId.openSettings:
        return;
    }
  }

  Future<void> _sendPrompt() async {
    final sent = await _sessionController.sendPrompt(
      _composerDraftHost.draft.text,
    );
    if (sent) {
      _transcriptFollowHost.requestFollow(
        source: ChatTranscriptFollowRequestSource.sendPrompt,
      );
      _composerDraftHost.clear();
    }
  }

  Future<void> _stopActiveTurn() async {
    await _sessionController.stopActiveTurn();
  }

  void _startFreshConversation() {
    _transcriptFollowHost.requestFollow(
      source: ChatTranscriptFollowRequestSource.newThread,
    );
    _sessionController.startFreshConversation();
  }

  void _clearTranscript() {
    _transcriptFollowHost.requestFollow(
      source: ChatTranscriptFollowRequestSource.clearTranscript,
    );
    _sessionController.clearTranscript();
  }

  void _handleScreenEffect(ChatScreenEffect effect) {
    switch (effect) {
      case ChatShowSnackBarEffect(:final message):
        _showSnackBar(message);
      case ChatOpenConnectionSettingsEffect(:final payload):
        unawaited(_openConnectionSettings(payload));
      case ChatOpenChangedFileDiffEffect(:final payload):
        unawaited(_openChangedFileDiff(payload));
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    widget.overlayDelegate.showSnackBar(context: context, message: message);
  }
}
