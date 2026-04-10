import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_controller.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';

typedef WorkspaceLiveSessionControllerEntry = ({
  String laneId,
  String connectionId,
  ChatSessionController sessionController,
});

Iterable<WorkspaceLiveSessionControllerEntry> workspaceLiveSessionControllers(
  ConnectionWorkspaceController workspaceController,
) sync* {
  for (final lane in workspaceController.state.liveLanes) {
    final binding = workspaceController.bindingForLaneId(lane.laneId);
    if (binding != null) {
      yield (
        laneId: lane.laneId,
        connectionId: lane.connectionId,
        sessionController: binding.sessionController,
      );
    }
  }
}

final class WorkspaceLiveSessionTracker extends ChangeNotifier {
  WorkspaceLiveSessionTracker(this._workspaceController) {
    _workspaceController.addListener(_handleWorkspaceChanged);
    _syncSessionControllers();
  }

  ConnectionWorkspaceController _workspaceController;
  final Map<String, ChatSessionController> _sessionControllersByLaneId =
      <String, ChatSessionController>{};
  bool _isDisposed = false;

  ConnectionWorkspaceController get workspaceController => _workspaceController;

  Map<String, ChatSessionController> get sessionControllersByLaneId =>
      Map<String, ChatSessionController>.unmodifiable(
        _sessionControllersByLaneId,
      );

  @Deprecated('Use sessionControllersByLaneId instead.')
  Map<String, ChatSessionController> get sessionControllersByConnectionId =>
      sessionControllersByLaneId;

  Iterable<ChatSessionController> get sessionControllers =>
      _sessionControllersByLaneId.values;

  void updateWorkspaceController(
    ConnectionWorkspaceController workspaceController,
  ) {
    if (identical(_workspaceController, workspaceController)) {
      return;
    }

    _workspaceController.removeListener(_handleWorkspaceChanged);
    _detachAllSessionControllers();
    _workspaceController = workspaceController;
    _workspaceController.addListener(_handleWorkspaceChanged);
    _syncSessionControllers();
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _workspaceController.removeListener(_handleWorkspaceChanged);
    _detachAllSessionControllers();
    _isDisposed = true;
    super.dispose();
  }

  void _handleWorkspaceChanged() {
    _syncSessionControllers();
    _notifyIfActive();
  }

  void _handleSessionChanged() {
    _notifyIfActive();
  }

  void _syncSessionControllers() {
    final nextControllersByLaneId = <String, ChatSessionController>{
      for (final entry in workspaceLiveSessionControllers(_workspaceController))
        entry.laneId: entry.sessionController,
    };

    final currentLaneIds = _sessionControllersByLaneId.keys.toSet();
    final nextLaneIds = nextControllersByLaneId.keys.toSet();

    for (final laneId in currentLaneIds.difference(nextLaneIds)) {
      _detachSessionController(laneId);
    }

    for (final entry in nextControllersByLaneId.entries) {
      final existingController = _sessionControllersByLaneId[entry.key];
      if (identical(existingController, entry.value)) {
        continue;
      }
      if (existingController != null) {
        _detachSessionController(entry.key);
      }
      _attachSessionController(entry.key, entry.value);
    }
  }

  void _attachSessionController(
    String laneId,
    ChatSessionController controller,
  ) {
    controller.addListener(_handleSessionChanged);
    _sessionControllersByLaneId[laneId] = controller;
  }

  void _detachSessionController(String laneId) {
    final controller = _sessionControllersByLaneId.remove(laneId);
    controller?.removeListener(_handleSessionChanged);
  }

  void _detachAllSessionControllers() {
    for (final laneId in _sessionControllersByLaneId.keys.toList()) {
      _detachSessionController(laneId);
    }
  }

  void _notifyIfActive() {
    if (_isDisposed) {
      return;
    }
    notifyListeners();
  }
}
