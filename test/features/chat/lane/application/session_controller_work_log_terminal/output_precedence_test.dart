import '../session_controller_test_support.dart';
import 'session_controller_work_log_terminal_test_support.dart';

void main() {
  test(
    'hydrateWorkLogTerminal reads nested result output and exit code',
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
                        'command': 'git status',
                        'result': <String, dynamic>{
                          'output': 'clean\n',
                          'exitCode': 23,
                        },
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
      final controller = buildWorkLogTerminalSessionController(
        appServerClient: appServerClient,
      );

      final hydrated = await controller.hydrateWorkLogTerminal(
        const ChatWorkLogTerminalContract(
          id: 'item_command_result',
          activityLabel: 'Ran command',
          commandText: 'git status',
          isRunning: false,
          isWaiting: false,
          itemId: 'command_result',
          threadId: 'thread_result',
          turnId: 'turn_result',
        ),
      );

      expect(hydrated.terminalOutput, 'clean\n');
      expect(hydrated.exitCode, 23);
      expect(hydrated.statusBadgeLabel, 'exit 23');
    },
  );

  test(
    'hydrateWorkLogTerminal combines split stdout and stderr history',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_streams'] =
            const CodexAppServerThreadHistory(
              id: 'thread_streams',
              turns: <CodexAppServerHistoryTurn>[
                CodexAppServerHistoryTurn(
                  id: 'turn_streams',
                  status: 'completed',
                  items: <CodexAppServerHistoryItem>[
                    CodexAppServerHistoryItem(
                      id: 'command_streams',
                      type: 'commandExecution',
                      status: 'completed',
                      raw: <String, dynamic>{
                        'id': 'command_streams',
                        'type': 'commandExecution',
                        'status': 'completed',
                        'command': 'build.sh',
                        'stdout': 'step 1\n',
                        'stderr': 'warning: cache miss\n',
                      },
                    ),
                  ],
                  raw: <String, dynamic>{
                    'id': 'turn_streams',
                    'status': 'completed',
                  },
                ),
              ],
            );
      final controller = buildWorkLogTerminalSessionController(
        appServerClient: appServerClient,
      );

      final hydrated = await controller.hydrateWorkLogTerminal(
        const ChatWorkLogTerminalContract(
          id: 'item_command_streams',
          activityLabel: 'Ran command',
          commandText: 'build.sh',
          isRunning: false,
          isWaiting: false,
          itemId: 'command_streams',
          threadId: 'thread_streams',
          turnId: 'turn_streams',
        ),
      );

      expect(hydrated.terminalOutput, 'step 1\nwarning: cache miss\n');
      expect(hydrated.activitySummary, isNull);
    },
  );

  test(
    'hydrateWorkLogTerminal preserves failed status without an exit code',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_failed'] =
            const CodexAppServerThreadHistory(
              id: 'thread_failed',
              turns: <CodexAppServerHistoryTurn>[
                CodexAppServerHistoryTurn(
                  id: 'turn_failed',
                  status: 'failed',
                  items: <CodexAppServerHistoryItem>[
                    CodexAppServerHistoryItem(
                      id: 'command_failed',
                      type: 'commandExecution',
                      status: 'failed',
                      raw: <String, dynamic>{
                        'id': 'command_failed',
                        'type': 'commandExecution',
                        'status': 'failed',
                        'command': 'make build',
                        'result': <String, dynamic>{'output': 'boom\n'},
                      },
                    ),
                  ],
                  raw: <String, dynamic>{
                    'id': 'turn_failed',
                    'status': 'failed',
                  },
                ),
              ],
            );
      final controller = buildWorkLogTerminalSessionController(
        appServerClient: appServerClient,
      );

      final hydrated = await controller.hydrateWorkLogTerminal(
        const ChatWorkLogTerminalContract(
          id: 'item_command_failed',
          activityLabel: 'Ran command',
          commandText: 'make build',
          isRunning: false,
          isWaiting: false,
          itemId: 'command_failed',
          threadId: 'thread_failed',
          turnId: 'turn_failed',
        ),
      );

      expect(hydrated.terminalOutput, 'boom\n');
      expect(hydrated.exitCode, isNull);
      expect(hydrated.isFailed, isTrue);
      expect(hydrated.statusBadgeLabel, 'failed');
    },
  );
}
