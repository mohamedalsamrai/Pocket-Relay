import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/cupertino_chat_composer.dart';

void main() {
  testWidgets('resyncs displayed text from the composer contract', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildComposerApp(
        contract: _composerContract(draftText: 'Initial draft'),
      ),
    );

    expect(
      tester
          .widget<CupertinoTextField>(find.byType(CupertinoTextField))
          .controller
          ?.text,
      'Initial draft',
    );

    await tester.pumpWidget(_buildComposerApp(contract: _composerContract()));

    expect(
      tester
          .widget<CupertinoTextField>(find.byType(CupertinoTextField))
          .controller
          ?.text,
      '',
    );
  });

  testWidgets('forwards text changes and send presses', (tester) async {
    String? latestValue;
    var sendCalls = 0;

    await tester.pumpWidget(
      _buildComposerApp(
        contract: _composerContract(),
        onChanged: (value) {
          latestValue = value;
        },
        onSend: () async {
          sendCalls += 1;
        },
      ),
    );

    await tester.enterText(find.byType(CupertinoTextField), 'Cupertino draft');
    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pumpAndSettle();

    expect(latestValue, 'Cupertino draft');
    expect(sendCalls, 1);
  });

  testWidgets('desktop enter sends the draft', (tester) async {
    var sendCalls = 0;

    await tester.pumpWidget(
      _buildComposerApp(
        platform: TargetPlatform.macOS,
        contract: _composerContract(),
        onSend: () async {
          sendCalls += 1;
        },
      ),
    );

    final fieldFinder = find.byType(CupertinoTextField);

    await tester.tap(fieldFinder);
    await tester.pump();
    await tester.enterText(fieldFinder, 'Desktop draft');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(sendCalls, 1);
    expect(
      tester.widget<CupertinoTextField>(fieldFinder).controller?.text,
      'Desktop draft',
    );
  });

  testWidgets('desktop shift+enter inserts a newline', (tester) async {
    var sendCalls = 0;

    await tester.pumpWidget(
      _buildComposerApp(
        platform: TargetPlatform.macOS,
        contract: _composerContract(),
        onSend: () async {
          sendCalls += 1;
        },
      ),
    );

    final fieldFinder = find.byType(CupertinoTextField);

    await tester.tap(fieldFinder);
    await tester.pump();
    await tester.enterText(fieldFinder, 'Desktop draft');
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(sendCalls, 0);
    expect(
      tester.widget<CupertinoTextField>(fieldFinder).controller?.text,
      'Desktop draft\n',
    );
  });

  testWidgets('mobile enter does not send and the draft remains multiline', (
    tester,
  ) async {
    var sendCalls = 0;

    await tester.pumpWidget(
      _buildComposerApp(
        platform: TargetPlatform.iOS,
        contract: _composerContract(),
        onSend: () async {
          sendCalls += 1;
        },
      ),
    );

    final fieldFinder = find.byType(CupertinoTextField);

    await tester.tap(fieldFinder);
    await tester.pump();
    await tester.enterText(fieldFinder, 'Mobile draft');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(sendCalls, 0);
    expect(
      tester.widget<CupertinoTextField>(fieldFinder).textInputAction,
      TextInputAction.newline,
    );

    await tester.enterText(fieldFinder, 'Mobile draft\nSecond line');
    await tester.pump();

    expect(
      tester.widget<CupertinoTextField>(fieldFinder).controller?.text,
      'Mobile draft\nSecond line',
    );
  });

  testWidgets(
    'keeps the send affordance stable while the active turn is running',
    (tester) async {
      await tester.pumpWidget(_buildComposerApp(contract: _composerContract()));

      expect(find.byKey(const ValueKey('send')), findsOneWidget);
      expect(find.byKey(const ValueKey('stop')), findsNothing);

      await tester.pumpWidget(
        _buildComposerApp(
          contract: _composerContract(isSendActionEnabled: false),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('send')), findsOneWidget);
      expect(find.byKey(const ValueKey('stop')), findsNothing);
    },
  );

  testWidgets('uses adaptive cupertino text colors in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildComposerApp(
        brightness: Brightness.dark,
        contract: _composerContract(),
      ),
    );

    final field = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField),
    );
    final surfaceContext = tester.element(
      find.byKey(const ValueKey('cupertino_composer_surface')),
    );
    final surface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('cupertino_composer_surface')),
    );
    final decoration = surface.decoration as BoxDecoration;

    expect(
      field.style?.color,
      CupertinoDynamicColor.resolve(CupertinoColors.label, surfaceContext),
    );
    expect(
      field.placeholderStyle?.color,
      CupertinoDynamicColor.resolve(
        CupertinoColors.placeholderText,
        surfaceContext,
      ),
    );
    expect(
      decoration.color,
      CupertinoDynamicColor.resolve(
        CupertinoColors.secondarySystemGroupedBackground,
        surfaceContext,
      ).withValues(alpha: 0.82),
    );
  });

  testWidgets('uses a compact centered layout in cupertino mode', (
    tester,
  ) async {
    await tester.pumpWidget(_buildComposerApp(contract: _composerContract()));

    final field = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField),
    );
    final contentRow = tester.widget<Row>(
      find.byKey(const ValueKey('chat_composer_content_row')),
    );

    expect(field.padding, const EdgeInsets.fromLTRB(2, 6, 8, 6));
    expect(contentRow.crossAxisAlignment, CrossAxisAlignment.center);
  });
}

Widget _buildComposerApp({
  required ChatComposerContract contract,
  Brightness brightness = Brightness.light,
  TargetPlatform platform = TargetPlatform.iOS,
  ValueChanged<String>? onChanged,
  Future<void> Function()? onSend,
}) {
  return MaterialApp(
    theme: buildPocketTheme(brightness).copyWith(platform: platform),
    darkTheme: buildPocketTheme(Brightness.dark).copyWith(platform: platform),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    home: Scaffold(
      body: CupertinoChatComposer(
        platformBehavior: PocketPlatformBehavior.resolve(platform: platform),
        contract: contract,
        onChanged: onChanged ?? (_) {},
        onSend: onSend ?? () async {},
      ),
    ),
  );
}

ChatComposerContract _composerContract({
  String draftText = '',
  bool isSendActionEnabled = true,
}) {
  return ChatComposerContract(
    draftText: draftText,
    isSendActionEnabled: isSendActionEnabled,
    placeholder: 'Message Codex',
  );
}
