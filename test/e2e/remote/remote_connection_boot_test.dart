import 'remote_connection_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'optional real-host saved-connection boot resolves remote continuity state',
    (tester) async {
      final harness = await pumpRealRemoteAppHarness(tester);
      await harness.openSavedConnectionsPage();
      await harness.waitForSettledRemoteProbe();

      final runtime = harness.requireSupportedRemoteRuntime();
      expect(runtime.hostCapability.isSupported, isTrue);
      expect(
        find.byKey(
          ValueKey<String>('saved_connection_${harness.connectionId}'),
        ),
        findsOneWidget,
      );
    },
    skip: realRemoteAppE2eConfig.skipReason != null,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
