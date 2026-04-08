import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_controller.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';

import '../session_controller_test_support.dart';

ChatSessionController buildWorkLogTerminalSessionController({
  required FakeCodexAppServerClient appServerClient,
}) {
  final savedProfile = SavedProfile(
    profile: configuredProfile(),
    secrets: const ConnectionSecrets(password: 'secret'),
  );
  addTearDown(appServerClient.close);

  final controller = ChatSessionController(
    profileStore: MemoryCodexProfileStore(initialValue: savedProfile),
    appServerClient: appServerClient,
    initialSavedProfile: savedProfile,
  );
  addTearDown(controller.dispose);
  return controller;
}
