import 'session_controller_test_support.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_work_log_terminal_contract.dart';

void main() {
  test(
    'hydrateWorkLogTerminal uses active turn data for running commands',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

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
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

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
}
