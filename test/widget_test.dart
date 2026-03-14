import 'package:codex_pocket/src/app.dart';
import 'package:codex_pocket/src/core/models/connection_models.dart';
import 'package:codex_pocket/src/core/storage/codex_profile_store.dart';
import 'package:codex_pocket/src/features/chat/services/ssh_codex_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the Codex Pocket shell', (tester) async {
    await tester.pumpWidget(
      CodexPocketApp(
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

    expect(find.text('Codex Pocket'), findsOneWidget);
    expect(find.text('Configure remote'), findsWidgets);
  });
}
