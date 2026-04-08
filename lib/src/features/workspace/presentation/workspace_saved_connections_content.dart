import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_panel_surface.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/widgets/chat_screen_shell.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_remote_runtime_probe.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_system_probe.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_system_template.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_lifecycle_errors.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_copy.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_lifecycle_presentation.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_lifecycle_widgets.dart';

part 'workspace_saved_connections_content_items.dart';
part 'workspace_saved_connections_content_actions.dart';
part 'workspace_saved_connections_content_shell.dart';

const double _savedConnectionsPanelRadius = 12;

class ConnectionWorkspaceSavedConnectionsContent extends StatefulWidget {
  const ConnectionWorkspaceSavedConnectionsContent({
    super.key,
    required this.workspaceController,
    required this.description,
    this.platformBehavior = const PocketPlatformBehavior(
      experience: PocketPlatformExperience.mobile,
      supportsLocalConnectionMode: false,
      supportsWakeLock: true,
      supportsFiniteBackgroundGrace: false,
      supportsActiveTurnForegroundService: false,
      supportsForegroundTurnCompletionSignal: true,
      supportsBackgroundTurnCompletionAlerts: true,
      usesDesktopKeyboardSubmit: false,
      supportsCollapsibleDesktopSidebar: false,
    ),
    this.settingsOverlayDelegate =
        const ModalConnectionSettingsOverlayDelegate(),
    this.useSafeArea = true,
  });

  final ConnectionWorkspaceController workspaceController;
  final String description;
  final PocketPlatformBehavior platformBehavior;
  final ConnectionSettingsOverlayDelegate settingsOverlayDelegate;
  final bool useSafeArea;

  @override
  State<ConnectionWorkspaceSavedConnectionsContent> createState() =>
      _ConnectionWorkspaceSavedConnectionsContentState();
}

class _ConnectionWorkspaceSavedConnectionsContentState
    extends State<ConnectionWorkspaceSavedConnectionsContent> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _instantiatingConnectionIds = <String>{};
  final Set<String> _reconnectingConnectionIds = <String>{};
  final Set<String> _editingConnectionIds = <String>{};
  final Set<String> _deletingConnectionIds = <String>{};
  final Set<String> _disconnectingConnectionIds = <String>{};
  final Set<String> _checkingHostConnectionIds = <String>{};
  final Map<String, ConnectionSettingsRemoteServerActionId>
  _activeRemoteServerActionsByConnectionId =
      <String, ConnectionSettingsRemoteServerActionId>{};
  final Set<String> _autoProbedRemoteRuntimeConnectionIds = <String>{};
  bool _isCreatingConnection = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspaceState = widget.workspaceController.state;
    final sections = connectionLifecycleSectionsFromState(
      workspaceState,
      isTransportConnected: _isTransportConnected,
    );
    _scheduleMissingRemoteRuntimeProbes(sections: sections);

    final content = _buildMaterialContent(context, sections: sections);

    final wrappedContent = widget.useSafeArea
        ? SafeArea(bottom: false, child: content)
        : content;

    final gradientBackground = ChatScreenGradientBackground(
      child: wrappedContent,
    );

    return Material(type: MaterialType.transparency, child: gradientBackground);
  }
}
