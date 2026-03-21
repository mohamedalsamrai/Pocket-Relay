import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/widgetbook/story_catalog.dart';
import 'package:widgetbook/widgetbook.dart';

class PocketRelayWidgetbook extends StatelessWidget {
  const PocketRelayWidgetbook({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      directories: buildPocketRelayWidgetbookCatalog(),
      addons: <WidgetbookAddon>[
        MaterialThemeAddon(
          themes: <WidgetbookTheme<ThemeData>>[
            WidgetbookTheme<ThemeData>(
              name: 'Pocket Light',
              data: buildPocketTheme(Brightness.light),
            ),
            WidgetbookTheme<ThemeData>(
              name: 'Pocket Dark',
              data: buildPocketTheme(Brightness.dark),
            ),
          ],
        ),
        ViewportAddon(<ViewportData>[
          Viewports.none,
          IosViewports.iPhone13,
          MacosViewports.desktop,
          MacosViewports.macbookPro,
        ]),
        TextScaleAddon(initialScale: 1.0, min: 0.8, max: 1.4, divisions: 3),
      ],
    );
  }
}
