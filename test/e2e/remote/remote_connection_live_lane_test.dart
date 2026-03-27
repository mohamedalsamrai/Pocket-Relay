import 'remote_connection_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'optional real-host production UI flow opens a live lane with an active remote thread',
    (tester) async {
      final harness = await pumpRealRemoteAppHarness(tester);
      await harness.openSavedConnectionsPage();
      await harness.waitForSettledRemoteProbe();
      harness.requireSupportedRemoteRuntime();
      await harness.openLiveLane();
      await harness.driveLiveLaneOnline();

      final threadId = await harness.sendPromptAndWaitForThread(
        'Reply with exactly: ok',
      );
      expect(harness.laneBinding.appServerClient.isConnected, isTrue);
      expect(threadId, isNotEmpty);

      final thread = await harness.laneBinding.appServerClient.readThread(
        threadId: threadId,
      );
      expect(thread.id, threadId);
    },
    skip: realRemoteAppE2eConfig.skipReason != null,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
