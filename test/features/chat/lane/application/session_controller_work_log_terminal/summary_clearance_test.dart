import '../session_controller_test_support.dart';

void main() {
  test(
    'hydrateWorkLogTerminal clears a stale activity summary once terminal output becomes available',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_result'] =
            const CodexAppServerThreadHistory(
              id: 'thread_result',
              turns: <CodexAppServerHistoryTurn>[
                CodexAppServerHistoryTurn(
                  id: 'turn_result',
                  status: 'completed',
                  items: <CodexAppServerHistoryItem>[
                    CodexAppServerHistoryItem(
                      id: 'command_result',
                      type: 'commandExecution',
                      status: 'completed',
                      raw: <String, dynamic>{
                        'id': 'command_result',
                        'type': 'commandExecution',
                        'status': 'completed',
                        'command': 'deploy.sh',
                        'result': <String, dynamic>{'output': 'done\n'},
                      },
                    ),
                  ],
                  raw: <String, dynamic>{
                    'id': 'turn_result',
                    'status': 'completed',
                  },
                ),
              ],
            );
      final controller = buildSessionController(
        appServerClient: appServerClient,
      );

      final hydrated = await controller.hydrateWorkLogTerminal(
        const ChatWorkLogTerminalContract(
          id: 'item_command_result',
          activityLabel: 'Ran command',
          commandText: 'deploy.sh',
          isRunning: false,
          isWaiting: false,
          itemId: 'command_result',
          threadId: 'thread_result',
          turnId: 'turn_result',
          activitySummary: 'Waiting on remote deployment slot',
        ),
      );

      expect(hydrated.terminalOutput, 'done\n');
      expect(hydrated.activitySummary, isNull);
    },
  );
}
