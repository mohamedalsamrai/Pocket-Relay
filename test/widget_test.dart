import 'package:pocket_relay/src/app.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/features/chat/services/ssh_codex_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the Pocket Relay shell', (tester) async {
    await tester.pumpWidget(
      PocketRelayApp(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: ConnectionProfile.defaults(),
            secrets: const ConnectionSecrets(),
          ),
        ),
        remoteService: SshCodexService(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Pocket Relay'), findsOneWidget);
    expect(find.text('Configure remote'), findsWidgets);
  });
}
