import 'dart:async';

import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/features/chat/runtime/application/agent_adapter_runtime_event_bridge.dart';
import 'package:pocket_relay/src/features/chat/runtime/application/host_adapter_runtime_event_mapper.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_reducer.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_models.dart';

abstract interface class ChatSessionEffectCoordinator {
  void handleAgentAdapterEvent(AgentAdapterEvent event);
  void applyRuntimeEvent(TranscriptRuntimeEvent event);
  void reportAppServerFailure({
    required PocketUserFacingError userFacingError,
    String? runtimeErrorMessage,
    bool suppressRuntimeError,
    bool suppressSnackBar,
  });
  void emitDiagnosticWarning(
    PocketUserFacingError warning, {
    required String rawMethod,
  });
}

abstract interface class ChatSessionEffectCoordinatorContext {
  AgentAdapterRuntimeEventMapper get runtimeEventMapper;
  TranscriptReducer get sessionReducer;
  TranscriptSessionState get sessionState;
  bool get isTrackingSshBootstrapFailures;
  set isTrackingSshBootstrapFailures(bool value);
  bool get sawTrackedSshBootstrapFailure;
  set sawTrackedSshBootstrapFailure(bool value);
  bool get sawTrackedUnpinnedHostKeyFailure;
  set sawTrackedUnpinnedHostKeyFailure(bool value);
  bool get isBufferingRuntimeEvents;

  void resetModelCatalogHydration();
  bool isUnsupportedHostRequest(String method);
  Future<void> handleUnsupportedHostRequest(AgentAdapterRequestEvent event);
  bool isSshBootstrapFailureRuntimeEvent(TranscriptRuntimeEvent event);
  void bufferRuntimeEvent(TranscriptRuntimeEvent event);
  void applySessionState(TranscriptSessionState nextState);
  void emitTurnCompleted({required String turnId, String? threadId});
  void hydrateThreadMetadataIfNeeded(TranscriptRuntimeThreadStartedEvent event);
  void emitSnackBar(String message);
}

class DefaultChatSessionEffectCoordinator
    implements ChatSessionEffectCoordinator {
  const DefaultChatSessionEffectCoordinator({required this.context});

  final ChatSessionEffectCoordinatorContext context;

  @override
  void handleAgentAdapterEvent(AgentAdapterEvent event) {
    if (event is AgentAdapterDisconnectedEvent) {
      context.resetModelCatalogHydration();
    }
    if (event is AgentAdapterRequestEvent &&
        context.isUnsupportedHostRequest(event.method)) {
      unawaited(context.handleUnsupportedHostRequest(event));
      return;
    }

    final runtimeEvents = context.runtimeEventMapper.mapEvent(event);
    final transcriptEvents = runtimeEvents
        .map(transcriptRuntimeEventFromAgentAdapter)
        .toList(growable: false);
    if (context.isTrackingSshBootstrapFailures &&
        transcriptEvents.any(context.isSshBootstrapFailureRuntimeEvent)) {
      context.sawTrackedSshBootstrapFailure = true;
    }
    if (context.isTrackingSshBootstrapFailures &&
        transcriptEvents.any(
          (event) => event is TranscriptRuntimeUnpinnedHostKeyEvent,
        )) {
      context.sawTrackedUnpinnedHostKeyFailure = true;
    }

    for (final runtimeEvent in transcriptEvents) {
      applyRuntimeEvent(runtimeEvent);
    }
  }

  @override
  void applyRuntimeEvent(TranscriptRuntimeEvent event) {
    if (context.isBufferingRuntimeEvents) {
      context.bufferRuntimeEvent(event);
      return;
    }

    context.applySessionState(
      context.sessionReducer.reduceRuntimeEvent(context.sessionState, event),
    );
    if (event is TranscriptRuntimeTurnCompletedEvent && event.turnId != null) {
      context.emitTurnCompleted(
        turnId: event.turnId!,
        threadId: event.threadId,
      );
    }
    if (event is TranscriptRuntimeThreadStartedEvent) {
      context.hydrateThreadMetadataIfNeeded(event);
    }
  }

  @override
  void reportAppServerFailure({
    required PocketUserFacingError userFacingError,
    String? runtimeErrorMessage,
    bool suppressRuntimeError = false,
    bool suppressSnackBar = false,
  }) {
    final now = DateTime.now();
    applyRuntimeEvent(
      TranscriptRuntimeSessionStateChangedEvent(
        createdAt: now,
        state: TranscriptRuntimeSessionState.ready,
        reason: userFacingError.message,
        rawMethod: 'app-server/failure',
      ),
    );
    if (!suppressRuntimeError) {
      applyRuntimeEvent(
        TranscriptRuntimeErrorEvent(
          createdAt: now,
          message: runtimeErrorMessage ?? userFacingError.inlineMessage,
          errorClass: TranscriptRuntimeErrorClass.transportError,
          rawMethod: 'app-server/failure',
        ),
      );
    }
    if (!suppressSnackBar) {
      context.emitSnackBar(userFacingError.inlineMessage);
    }
  }

  @override
  void emitDiagnosticWarning(
    PocketUserFacingError warning, {
    required String rawMethod,
  }) {
    applyRuntimeEvent(
      TranscriptRuntimeWarningEvent(
        createdAt: DateTime.now(),
        rawMethod: rawMethod,
        summary: warning.bodyWithCode,
      ),
    );
  }
}
