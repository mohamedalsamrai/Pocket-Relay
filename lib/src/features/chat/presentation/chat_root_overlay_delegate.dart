import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/changed_files_card.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_sheet.dart';

abstract interface class ChatRootOverlayDelegate {
  Future<ConnectionSettingsSubmitPayload?> openConnectionSettings({
    required BuildContext context,
    required ChatConnectionSettingsLaunchContract connectionSettings,
  });

  Future<void> openChangedFileDiff({
    required BuildContext context,
    required ChatChangedFileDiffContract diff,
  });

  void showSnackBar({required BuildContext context, required String message});
}

class FlutterChatRootOverlayDelegate implements ChatRootOverlayDelegate {
  const FlutterChatRootOverlayDelegate();

  @override
  Future<ConnectionSettingsSubmitPayload?> openConnectionSettings({
    required BuildContext context,
    required ChatConnectionSettingsLaunchContract connectionSettings,
  }) {
    return showModalBottomSheet<ConnectionSettingsSubmitPayload>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ConnectionSheet(
          initialProfile: connectionSettings.initialProfile,
          initialSecrets: connectionSettings.initialSecrets,
        );
      },
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
  void showSnackBar({required BuildContext context, required String message}) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
