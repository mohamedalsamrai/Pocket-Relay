import 'package:pocket_relay/widgetbook/catalog/app_story_catalog.dart';
import 'package:pocket_relay/widgetbook/catalog/chat_story_catalog.dart';
import 'package:pocket_relay/widgetbook/catalog/core_ui_story_catalog.dart';
import 'package:pocket_relay/widgetbook/catalog/settings_story_catalog.dart';
import 'package:widgetbook/widgetbook.dart';

List<WidgetbookNode> buildPocketRelayWidgetbookCatalog() {
  return <WidgetbookNode>[
    buildCoreUiWidgetbookCategory(),
    buildChatWidgetbookCategory(),
    buildSettingsWidgetbookCategory(),
    buildAppWidgetbookCategory(),
  ];
}
