import 'package:pocket_relay/src/app/pocket_relay_app.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
import 'package:pocket_relay/widgetbook/support/widgetbook_fixtures.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookCategory buildAppWidgetbookCategory() {
  return WidgetbookCategory(
    name: 'App',
    children: <WidgetbookNode>[
      WidgetbookComponent(
        name: 'Workspace',
        useCases: <WidgetbookUseCase>[
          WidgetbookUseCase(
            name: 'Mobile Workspace',
            builder: (_) => PocketRelayApp(
              connectionRepository: MemoryCodexConnectionRepository.single(
                savedProfile: WidgetbookFixtures.savedProfile,
              ),
              agentAdapterClient: FakeCodexAppServerClient(),
              displayWakeLockController: const NoopDisplayWakeLockController(),
              platformPolicy: WidgetbookFixtures.mobilePolicy,
            ),
          ),
          WidgetbookUseCase(
            name: 'Desktop Workspace',
            builder: (_) => PocketRelayApp(
              connectionRepository: MemoryCodexConnectionRepository.single(
                savedProfile: WidgetbookFixtures.savedProfile,
              ),
              agentAdapterClient: FakeCodexAppServerClient(),
              displayWakeLockController: const NoopDisplayWakeLockController(),
              platformPolicy: WidgetbookFixtures.desktopPolicy,
            ),
          ),
        ],
      ),
    ],
  );
}
