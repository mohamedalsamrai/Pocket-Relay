import 'package:pocket_relay/src/agent_adapters/agent_adapter_registry.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_host.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_sheet.dart';
import 'package:pocket_relay/widgetbook/catalog/story_catalog_layout.dart';
import 'package:pocket_relay/widgetbook/support/widgetbook_fixtures.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookCategory buildSettingsWidgetbookCategory() {
  return WidgetbookCategory(
    name: 'Settings',
    children: <WidgetbookNode>[
      WidgetbookComponent(
        name: 'Connection Sheet',
        useCases: <WidgetbookUseCase>[
          WidgetbookUseCase(
            name: 'Remote Password',
            builder: (_) => widgetbookStoryFill(
              maxWidth: 920,
              child: ConnectionSettingsHost(
                initialProfile: WidgetbookFixtures.remoteProfile,
                initialSecrets: WidgetbookFixtures.passwordSecrets,
                availableModelCatalog: referenceModelCatalogForAgentAdapter(
                  AgentAdapterKind.codex,
                  connectionId: 'widgetbook-remote',
                ),
                platformBehavior: WidgetbookFixtures.desktopBehavior,
                onCancel: () {},
                onSubmit: (_) {},
                builder: (context, viewModel, actions) {
                  return ConnectionSheet(
                    platformBehavior: WidgetbookFixtures.desktopBehavior,
                    viewModel: viewModel,
                    actions: actions,
                  );
                },
              ),
            ),
          ),
          WidgetbookUseCase(
            name: 'Local Workspace',
            builder: (_) => widgetbookStoryFill(
              maxWidth: 920,
              child: ConnectionSettingsHost(
                initialProfile: WidgetbookFixtures.localProfile,
                initialSecrets: const ConnectionSecrets(),
                availableModelCatalog: referenceModelCatalogForAgentAdapter(
                  AgentAdapterKind.codex,
                  connectionId: 'widgetbook-local',
                ),
                platformBehavior: WidgetbookFixtures.desktopBehavior,
                onCancel: () {},
                onSubmit: (_) {},
                builder: (context, viewModel, actions) {
                  return ConnectionSheet(
                    platformBehavior: WidgetbookFixtures.desktopBehavior,
                    viewModel: viewModel,
                    actions: actions,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
