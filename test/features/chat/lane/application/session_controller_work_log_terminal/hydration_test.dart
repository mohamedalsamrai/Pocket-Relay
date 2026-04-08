import '../session_controller_test_support.dart';
import 'session_controller_work_log_terminal_test_support.dart';

void main() {
  test(
    'hydrateWorkLogTerminal uses active turn data for running commands',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      final controller = buildWorkLogTerminalSessionController(
        appServerClient: appServerClient,
      );

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/started',
          params: <String, Object?>{
            'threadId': 'thread_live',
            'turnId': 'turn_live',
            'item': <String, Object?>{
              'id': 'command_live',
              'type': 'commandExecution',
              'status': 'inProgress',
              'command': 'python demo.py',
              'processId': 'proc_live',
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/commandExecution/terminalInteraction',
          params: <String, Object?>{
            'threadId': 'thread_live',
            'turnId': 'turn_live',
            'itemId': 'command_live',
            'processId': 'proc_live',
            'stdin': 'y\n',
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/commandExecution/outputDelta',
          params: <String, Object?>{
            'threadId': 'thread_live',
            'turnId': 'turn_live',
            'itemId': 'command_live',
            'delta': 'continuing...\n',
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final hydrated = await controller.hydrateWorkLogTerminal(
        const ChatWorkLogTerminalContract(
          id: 'item_command_live',
          activityLabel: 'Running command',
          commandText: 'python demo.py',
          isRunning: true,
          isWaiting: false,
          itemId: 'command_live',
          threadId: 'thread_live',
          turnId: 'turn_live',
        ),
      );

      expect(hydrated.commandText, 'python demo.py');
      expect(hydrated.processId, 'proc_live');
      expect(hydrated.terminalInput, 'y\n');
      expect(hydrated.terminalOutput, 'continuing...\n');
      expect(appServerClient.readThreadCalls, isEmpty);
    },
  );

  test(
    'hydrateWorkLogTerminal reads historical thread output for completed commands',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] =
            const CodexAppServerThreadHistory(
              id: 'thread_saved',
              turns: <CodexAppServerHistoryTurn>[
                CodexAppServerHistoryTurn(
                  id: 'turn_saved',
                  status: 'completed',
                  items: <CodexAppServerHistoryItem>[
                    CodexAppServerHistoryItem(
                      id: 'command_saved',
                      type: 'commandExecution',
                      status: 'completed',
                      raw: <String, dynamic>{
                        'id': 'command_saved',
                        'type': 'commandExecution',
                        'status': 'completed',
                        'command': 'pwd',
                        'aggregatedOutput': '/repo\n',
                        'exitCode': 0,
                      },
                    ),
                  ],
                  raw: <String, dynamic>{
                    'id': 'turn_saved',
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
          id: 'item_command_saved',
          activityLabel: 'Ran command',
          commandText: 'pwd',
          isRunning: false,
          isWaiting: false,
          itemId: 'command_saved',
          threadId: 'thread_saved',
          turnId: 'turn_saved',
        ),
      );

      expect(appServerClient.readThreadCalls, <String>['thread_saved']);
      expect(hydrated.commandText, 'pwd');
      expect(hydrated.terminalOutput, '/repo\n');
      expect(hydrated.exitCode, 0);
    },
  );

  test(
    'hydrateWorkLogTerminal ignores active items from a different turn id',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_shared'] =
            const CodexAppServerThreadHistory(
              id: 'thread_shared',
              turns: <CodexAppServerHistoryTurn>[
                CodexAppServerHistoryTurn(
                  id: 'turn_old',
                  status: 'completed',
                  items: <CodexAppServerHistoryItem>[
                    CodexAppServerHistoryItem(
                      id: 'shared_command',
                      type: 'commandExecution',
                      status: 'completed',
                      raw: <String, dynamic>{
                        'id': 'shared_command',
                        'type': 'commandExecution',
                        'status': 'completed',
                        'command': 'pwd',
                        'aggregatedOutput': '/repo/old\n',
                      },
                    ),
                  ],
                  raw: <String, dynamic>{
                    'id': 'turn_old',
                    'status': 'completed',
                  },
                ),
                CodexAppServerHistoryTurn(
                  id: 'turn_new',
                  status: 'in_progress',
                  items: <CodexAppServerHistoryItem>[
                    CodexAppServerHistoryItem(
                      id: 'shared_command',
                      type: 'commandExecution',
                      status: 'in_progress',
                      raw: <String, dynamic>{
                        'id': 'shared_command',
                        'type': 'commandExecution',
                        'status': 'in_progress',
                        'command': 'pwd',
                        'aggregatedOutput': '/repo/new\n',
                      },
                    ),
                  ],
                  raw: <String, dynamic>{
                    'id': 'turn_new',
                    'status': 'in_progress',
                  },
                ),
              ],
            );
      final controller = buildWorkLogTerminalSessionController(
        appServerClient: appServerClient,
      );

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/started',
          params: <String, Object?>{
            'threadId': 'thread_shared',
            'turnId': 'turn_new',
            'item': <String, Object?>{
              'id': 'shared_command',
              'type': 'commandExecution',
              'status': 'inProgress',
              'command': 'pwd',
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/commandExecution/outputDelta',
          params: <String, Object?>{
            'threadId': 'thread_shared',
            'turnId': 'turn_new',
            'itemId': 'shared_command',
            'delta': '/repo/live\n',
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final hydrated = await controller.hydrateWorkLogTerminal(
        const ChatWorkLogTerminalContract(
          id: 'item_shared_command',
          activityLabel: 'Ran command',
          commandText: 'pwd',
          isRunning: false,
          isWaiting: false,
          itemId: 'shared_command',
          threadId: 'thread_shared',
          turnId: 'turn_old',
        ),
      );

      expect(appServerClient.readThreadCalls, <String>['thread_shared']);
      expect(hydrated.terminalOutput, '/repo/old\n');
      expect(hydrated.isRunning, isFalse);
    },
  );
}
