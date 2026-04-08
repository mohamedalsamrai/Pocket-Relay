import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/widgets/modal_sheet_scaffold.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_host.dart';

part 'sheet/connection_settings_sheet_scaffold.dart';
part 'sheet/connection_settings_sheet_header.dart';
part 'sheet/connection_settings_sheet_sections.dart';
part 'sheet/connection_settings_sheet_status.dart';
part 'sheet/connection_settings_sheet_fields.dart';

enum ConnectionSettingsSurfaceMode { workspace, system }

const double _mobileHorizontalPadding = 20;
const double _mobileHeaderTopPadding = 16;
const double _mobileHeaderBottomPadding = 18;
const double _mobileContentTopPadding = 20;
const double _mobileFooterBottomPadding = 16;

const double _desktopSurfacePadding = 24;
const double _desktopSurfaceVerticalMargin = _desktopSurfacePadding * 2;
const double _desktopSurfaceMaxWidth = 880;
const double _desktopSurfaceHeaderBottomPadding = 18;
const double _desktopSurfaceContentTopPadding = 20;
const double _desktopSurfaceElevation = 18;
const double _desktopSurfaceRadius = 32;

const double _sectionSpacing = 28;
const double _sectionDividerSpacing = 24;
const double _fieldSpacing = 12;
const double _subsectionSpacing = 14;
const double _modelRefreshSpacing = 16;
const double _modelDefaultsSplitLayoutBreakpoint = 640;

class ConnectionSettingsSheetSurface extends StatelessWidget {
  const ConnectionSettingsSheetSurface({
    super.key,
    required this.viewModel,
    required this.actions,
    this.isDesktopPresentation = false,
    this.surfaceMode = ConnectionSettingsSurfaceMode.workspace,
  });

  final ConnectionSettingsHostViewModel viewModel;
  final ConnectionSettingsHostActions actions;
  final bool isDesktopPresentation;
  final ConnectionSettingsSurfaceMode surfaceMode;

  @override
  Widget build(BuildContext context) {
    final contract = viewModel.contract;
    return isDesktopPresentation
        ? this._buildDesktopSurface(context, contract)
        : this._buildMaterialSurface(context, contract);
  }
}
