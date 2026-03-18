import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/cupertino_transient_feedback.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/changed_files_card.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_renderer.dart';

enum ChatTransientFeedbackRenderer { material, cupertino }

abstract interface class ChatRootOverlayDelegate {
  Future<ConnectionSettingsSubmitPayload?> openConnectionSettings({
    required BuildContext context,
    required ChatConnectionSettingsLaunchContract connectionSettings,
    required PocketPlatformBehavior platformBehavior,
    required ConnectionSettingsRenderer renderer,
  });

  Future<void> openChangedFileDiff({
    required BuildContext context,
    required ChatChangedFileDiffContract diff,
  });

  void showTransientFeedback({
    required BuildContext context,
    required String message,
    required ChatTransientFeedbackRenderer renderer,
  });
}

class FlutterChatRootOverlayDelegate implements ChatRootOverlayDelegate {
  const FlutterChatRootOverlayDelegate({
    ConnectionSettingsOverlayDelegate settingsOverlayDelegate =
        const ModalConnectionSettingsOverlayDelegate(),
  }) : _settingsOverlayDelegate = settingsOverlayDelegate;

  final ConnectionSettingsOverlayDelegate _settingsOverlayDelegate;

  @override
  Future<ConnectionSettingsSubmitPayload?> openConnectionSettings({
    required BuildContext context,
    required ChatConnectionSettingsLaunchContract connectionSettings,
    required PocketPlatformBehavior platformBehavior,
    required ConnectionSettingsRenderer renderer,
  }) {
    return _settingsOverlayDelegate.openConnectionSettings(
      context: context,
      initialProfile: connectionSettings.initialProfile,
      initialSecrets: connectionSettings.initialSecrets,
      platformBehavior: platformBehavior,
      renderer: renderer,
    );
  }

  @override
  Future<void> openChangedFileDiff({
    required BuildContext context,
    required ChatChangedFileDiffContract diff,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ChangedFileDiffSheet(diff: diff);
      },
    );
  }

  @override
  void showTransientFeedback({
    required BuildContext context,
    required String message,
    required ChatTransientFeedbackRenderer renderer,
  }) {
    switch (renderer) {
      case ChatTransientFeedbackRenderer.material:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      case ChatTransientFeedbackRenderer.cupertino:
        const CupertinoTransientFeedbackPresenter().show(
          context: context,
          message: message,
        );
    }
  }
}
