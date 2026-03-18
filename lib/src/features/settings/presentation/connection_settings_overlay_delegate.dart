import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';

import 'connection_settings_contract.dart';
import 'connection_settings_host.dart';
import 'connection_settings_renderer.dart';
import 'connection_sheet.dart';
import 'cupertino_connection_sheet.dart';

abstract interface class ConnectionSettingsOverlayDelegate {
  Future<ConnectionSettingsSubmitPayload?> openConnectionSettings({
    required BuildContext context,
    required ConnectionProfile initialProfile,
    required ConnectionSecrets initialSecrets,
    required PocketPlatformBehavior platformBehavior,
    required ConnectionSettingsRenderer renderer,
  });
}

class ModalConnectionSettingsOverlayDelegate
    implements ConnectionSettingsOverlayDelegate {
  const ModalConnectionSettingsOverlayDelegate();

  @override
  Future<ConnectionSettingsSubmitPayload?> openConnectionSettings({
    required BuildContext context,
    required ConnectionProfile initialProfile,
    required ConnectionSecrets initialSecrets,
    required PocketPlatformBehavior platformBehavior,
    required ConnectionSettingsRenderer renderer,
  }) {
    return switch (renderer) {
      ConnectionSettingsRenderer.material =>
        showModalBottomSheet<ConnectionSettingsSubmitPayload>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (sheetContext) {
            return ConnectionSettingsHost(
              initialProfile: initialProfile,
              initialSecrets: initialSecrets,
              platformBehavior: platformBehavior,
              onCancel: () => Navigator.of(sheetContext).pop(),
              onSubmit: (payload) {
                Navigator.of(sheetContext).pop(payload);
              },
              builder: (context, viewModel, actions) {
                return ConnectionSheet(viewModel: viewModel, actions: actions);
              },
            );
          },
        ),
      ConnectionSettingsRenderer.cupertino =>
        showCupertinoModalPopup<ConnectionSettingsSubmitPayload>(
          context: context,
          builder: (sheetContext) {
            return ConnectionSettingsHost(
              initialProfile: initialProfile,
              initialSecrets: initialSecrets,
              platformBehavior: platformBehavior,
              onCancel: () => Navigator.of(sheetContext).pop(),
              onSubmit: (payload) {
                Navigator.of(sheetContext).pop(payload);
              },
              builder: (context, viewModel, actions) {
                return CupertinoConnectionSheet(
                  viewModel: viewModel,
                  actions: actions,
                );
              },
            );
          },
        ),
    };
  }
}
