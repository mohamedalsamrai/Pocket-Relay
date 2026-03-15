import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_host.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_sheet_surface.dart';

class CupertinoConnectionSheet extends StatelessWidget {
  const CupertinoConnectionSheet({
    super.key,
    required this.viewModel,
    required this.actions,
  });

  final ConnectionSettingsHostViewModel viewModel;
  final ConnectionSettingsHostActions actions;

  @override
  Widget build(BuildContext context) {
    return ConnectionSettingsSheetSurface(
      viewModel: viewModel,
      actions: actions,
      style: ConnectionSettingsSheetStyle.cupertino,
    );
  }
}
