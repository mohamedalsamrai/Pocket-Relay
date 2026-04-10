import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_panel_surface.dart';
import 'package:pocket_relay/src/core/widgets/modal_sheet_scaffold.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_sheet.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_sheet_surface.dart';

import '../host_test_support.dart';

void main() {
  testWidgets(
    'material settings renderer keeps the action bar pinned while the form scrolls',
    (tester) async {
      tester.view.physicalSize = const Size(430, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildMaterialSettingsApp(onSubmit: (_) {}));

      expect(
        find.byKey(const ValueKey<String>('connection_settings_cancel_top')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('connection_settings_save_top')),
        findsOneWidget,
      );
      expect(find.text('Danger zone'), findsNothing);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('connection_settings_cancel_top')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('connection_settings_save_top')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'mobile system settings move save actions into the scroll body when the keyboard is open',
    (tester) async {
      const screenSize = Size(390, 720);
      const keyboardInset = 320.0;
      final visibleBottom = screenSize.height - keyboardInset;
      tester.view.physicalSize = screenSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildPocketTheme(Brightness.light),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                size: screenSize,
                viewInsets: EdgeInsets.only(bottom: keyboardInset),
              ),
              child: buildSettingsHost(
                onSubmit: (_) {},
                surfaceMode: ConnectionSettingsSurfaceMode.system,
                builder: (context, viewModel, actions) {
                  return ConnectionSheet(
                    platformBehavior: mobileSettingsBehavior,
                    viewModel: viewModel,
                    actions: actions,
                    surfaceMode: ConnectionSettingsSurfaceMode.system,
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getBottomRight(materialTextField('System name')).dy,
        lessThan(visibleBottom),
      );
      expect(
        tester.getBottomRight(materialTextField('Host')).dy,
        lessThan(visibleBottom),
      );

      final saveButton = find.byKey(
        const ValueKey<String>('connection_settings_save_top'),
      );
      expect(
        tester.getTopLeft(saveButton).dy,
        greaterThanOrEqualTo(visibleBottom),
      );

      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      expect(tester.getBottomRight(saveButton).dy, lessThan(visibleBottom));
    },
  );

  testWidgets(
    'mobile settings header avoids fixed explanatory prose and route badges',
    (tester) async {
      await tester.pumpWidget(buildMaterialSettingsApp(onSubmit: (_) {}));

      expect(
        find.text(
          'Choose the system that hosts this workspace, then point Pocket Relay at the directory and Codex command it should use there.',
        ),
        findsNothing,
      );
      expect(find.text('Remote'), findsNothing);
      expect(find.text('Local'), findsNothing);
      expect(find.text('devbox.local · /workspace'), findsOneWidget);
    },
  );

  testWidgets(
    'material settings renderer avoids nested panel surfaces inside the drawer',
    (tester) async {
      await tester.pumpWidget(buildMaterialSettingsApp(onSubmit: (_) {}));

      expect(find.byType(PocketPanelSurface), findsNothing);
    },
  );

  testWidgets(
    'desktop settings use centered desktop chrome without the sheet drag handle',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        buildMaterialSettingsApp(
          onSubmit: (_) {},
          platformBehavior: desktopSettingsBehavior,
        ),
      );

      expect(
        find.byKey(
          const ValueKey<String>('desktop_connection_settings_surface'),
        ),
        findsOneWidget,
      );
      expect(find.byType(ModalSheetDragHandle), findsNothing);
    },
  );
}
