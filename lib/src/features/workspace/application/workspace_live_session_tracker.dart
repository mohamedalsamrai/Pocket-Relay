import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_controller.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';

typedef WorkspaceLiveSessionControllerEntry = ({
  String connectionId,
  ChatSessionController sessionController,
});

Iterable<WorkspaceLiveSessionControllerEntry> workspaceLiveSessionControllers(
  ConnectionWorkspaceController workspaceController,
) sync* {
  for (final connectionId in workspaceController.state.liveConnectionIds) {
    final binding = workspaceController.bindingForConnectionId(connectionId);
    if (binding != null) {
      yield (
        connectionId: connectionId,
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
  final Map<String, ChatSessionController> _sessionControllersByConnectionId =
      <String, ChatSessionController>{};
  bool _isDisposed = false;

  ConnectionWorkspaceController get workspaceController => _workspaceController;

  Map<String, ChatSessionController> get sessionControllersByConnectionId =>
      Map<String, ChatSessionController>.unmodifiable(
        _sessionControllersByConnectionId,
      );

  Iterable<ChatSessionController> get sessionControllers =>
      _sessionControllersByConnectionId.values;

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
    final nextControllersByConnectionId = <String, ChatSessionController>{
      for (final entry in workspaceLiveSessionControllers(_workspaceController))
        entry.connectionId: entry.sessionController,
    };

    final currentConnectionIds = _sessionControllersByConnectionId.keys.toSet();
    final nextConnectionIds = nextControllersByConnectionId.keys.toSet();

    for (final connectionId in currentConnectionIds.difference(
      nextConnectionIds,
    )) {
      _detachSessionController(connectionId);
    }

    for (final entry in nextControllersByConnectionId.entries) {
      final existingController = _sessionControllersByConnectionId[entry.key];
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
    String connectionId,
    ChatSessionController controller,
  ) {
    controller.addListener(_handleSessionChanged);
    _sessionControllersByConnectionId[connectionId] = controller;
  }

  void _detachSessionController(String connectionId) {
    final controller = _sessionControllersByConnectionId.remove(connectionId);
    controller?.removeListener(_handleSessionChanged);
  }

  void _detachAllSessionControllers() {
    for (final connectionId
        in _sessionControllersByConnectionId.keys.toList()) {
      _detachSessionController(connectionId);
    }
  }

  void _notifyIfActive() {
    if (_isDisposed) {
      return;
    }
    notifyListeners();
  }
}
