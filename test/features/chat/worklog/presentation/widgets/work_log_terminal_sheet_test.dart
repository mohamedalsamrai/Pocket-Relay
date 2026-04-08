import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/theme/pocket_typography.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_work_log_terminal_contract.dart';
import 'package:pocket_relay/src/features/chat/worklog/presentation/widgets/work_log_terminal_sheet.dart';

void main() {
  testWidgets('uses the app-owned monospace family for terminal text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPocketTheme(Brightness.light),
        home: const Scaffold(
          body: WorkLogTerminalSheet(
            terminal: ChatWorkLogTerminalContract(
              id: 'terminal_1',
              activityLabel: 'Ran command',
              commandText: 'pwd',
              isRunning: false,
              isWaiting: false,
              terminalOutput: '/workspace\n',
            ),
          ),
        ),
      ),
    );

    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(text.style?.fontFamily, PocketFontFamilies.monospace);
  });

  testWidgets(
    'shows a truthful non-transcript activity message instead of a false empty-terminal state',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildPocketTheme(Brightness.light),
          home: const Scaffold(
            body: WorkLogTerminalSheet(
              terminal: ChatWorkLogTerminalContract(
                id: 'terminal_2',
                activityLabel: 'Ran command',
                commandText: 'deploy.sh',
                isRunning: false,
                isWaiting: false,
                activitySummary: 'Waiting on remote deployment slot',
              ),
            ),
          ),
        ),
      );

      final text = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(
        text.data,
        contains(
          'Runtime activity was recorded, but no terminal transcript was available.',
        ),
      );
      expect(
        text.data,
        contains('Latest activity: Waiting on remote deployment slot'),
      );
      expect(text.data, isNot(contains('No terminal output captured.')));
    },
  );

  testWidgets('keeps waiting and empty terminal states distinct', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPocketTheme(Brightness.light),
        home: const Scaffold(
          body: WorkLogTerminalSheet(
            terminal: ChatWorkLogTerminalContract(
              id: 'terminal_3',
              activityLabel: 'Waiting for background terminal',
              commandText: 'sleep 5',
              isRunning: true,
              isWaiting: true,
              activitySummary: 'still running',
            ),
          ),
        ),
      ),
    );

    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(text.data, contains('Waiting for terminal output...'));
    expect(text.data, contains('Latest activity: still running'));
    expect(text.data, isNot(contains('No terminal output captured.')));
  });
}
