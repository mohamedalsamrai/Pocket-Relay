import 'remote_connection_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'optional real-host live lane can start the managed owner and connect',
    (tester) async {
      final harness = await pumpRealRemoteAppHarness(tester);
      await harness.openSavedConnectionsPage();
      await harness.waitForSettledRemoteProbe();
      harness.requireSupportedRemoteRuntime();
      await harness.openLiveLane();
      await harness.driveLiveLaneOnline();

      expect(harness.laneBinding.appServerClient.isConnected, isTrue);
      expect(
        harness.laneBinding.sessionController.sessionState.connectionStatus,
        isNotNull,
      );
    },
    skip: realRemoteAppE2eConfig.skipReason != null,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
