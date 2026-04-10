import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/secure/secure_connection_repository_keys.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/widgets/flutter_chat_screen_renderer.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/testing/fake_agent_adapter_client.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_desktop_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/builders/app_test_harness.dart';
import '../core/storage/support/connection_repository_test_support.dart';

void main() {
  registerAppTestStorageLifecycle();

  testWidgets(
    'shows the material bootstrap shell while the catalog is loading on iOS',
    (tester) async {
      final connectionRepository = DeferredConnectionRepository();
      final appServerClient = FakeAgentAdapterClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(
          connectionRepository: connectionRepository,
          agentAdapterClient: appServerClient,
        ),
      );
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Pocket Relay'), findsOneWidget);
      expect(
        find.text('Loading saved connections and workspace state.'),
        findsOneWidget,
      );
      expect(find.byType(Image), findsOneWidget);

      connectionRepository.complete(testSavedProfile());
      await tester.pumpAndSettle();

      expect(find.byType(FlutterChatScreenRenderer), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'shows a retry action when workspace bootstrap initialization fails',
    (tester) async {
      final connectionRepository = FailOnceConnectionRepository(
        savedConnection: buildSavedConnection(),
      );
      final appServerClient = FakeAgentAdapterClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(
          connectionRepository: connectionRepository,
          agentAdapterClient: appServerClient,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          '[${PocketErrorCatalog.appBootstrapWorkspaceInitializationFailed.code}]',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Workspace load failed'), findsOneWidget);
      expect(find.textContaining('catalog load failed'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('retry_workspace_bootstrap')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('retry_workspace_bootstrap')));
      await tester.pumpAndSettle();

      expect(find.byType(FlutterChatScreenRenderer), findsOneWidget);
      expect(connectionRepository.loadCatalogCalls, 2);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'boots the macOS workspace shell when legacy secure secret reads fail during migration',
    (tester) async {
      final legacyProfile = ConnectionProfile.defaults().copyWith(
        host: 'relay.example.com',
        username: 'vince',
        workspaceDir: '/workspace/app',
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        'pocket_relay.connections.index': jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'orderedConnectionIds': <String>['conn_seed'],
        }),
        'pocket_relay.connection.conn_seed.profile': jsonEncode(
          legacyProfile.toJson(),
        ),
      });
      final secureStorage = ThrowingReadFakeFlutterSecureStorage(
        <String, String>{passwordKeyForConnection('conn_seed'): 'secret'},
        keyToThrowOn: passwordKeyForConnection('conn_seed'),
      );
      final preferences = SharedPreferencesAsync();
      final repository = buildSecureConnectionRepository(
        secureStorage: secureStorage,
        preferences: preferences,
        connectionIdGenerator: () => 'conn_unused',
        systemIdGenerator: () => 'system_seed',
      );
      final appServerClient = FakeAgentAdapterClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(
          connectionRepository: repository,
          agentAdapterClient: appServerClient,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          '[${PocketErrorCatalog.appBootstrapWorkspaceInitializationFailed.code}]',
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('retry_workspace_bootstrap')),
        findsNothing,
      );
      expect(find.byType(ConnectionWorkspaceDesktopShell), findsOneWidget);
      expect(find.byType(FlutterChatScreenRenderer), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}
