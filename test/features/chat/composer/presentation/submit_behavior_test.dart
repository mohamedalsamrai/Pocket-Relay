import '../support/composer_test_support.dart';

void main() {
  testWidgets('desktop enter sends the draft', (tester) async {
    var sendCalls = 0;

    await tester.pumpWidget(
      buildComposerApp(
        platform: TargetPlatform.macOS,
        contract: composerContract(),
        onSend: () async {
          sendCalls += 1;
        },
      ),
    );

    final fieldFinder = find.byType(TextField);

    await tester.tap(fieldFinder);
    await tester.pump();
    await tester.enterText(fieldFinder, 'Desktop draft');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(sendCalls, 1);
    expect(
      tester.widget<TextField>(fieldFinder).controller?.text,
      'Desktop draft',
    );
  });

  testWidgets('desktop shift+enter inserts a newline', (tester) async {
    var sendCalls = 0;

    await tester.pumpWidget(
      buildComposerApp(
        platform: TargetPlatform.macOS,
        contract: composerContract(),
        onSend: () async {
          sendCalls += 1;
        },
      ),
    );

    final fieldFinder = find.byType(TextField);

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
      tester.widget<TextField>(fieldFinder).controller?.text,
      'Desktop draft\n',
    );
  });

  testWidgets(
    'desktop enter submits immediately after typing before the next rebuild',
    (tester) async {
      var sendCalls = 0;

      await tester.pumpWidget(
        buildComposerApp(
          platform: TargetPlatform.macOS,
          contract: composerContract(),
          onSend: () async {
            sendCalls += 1;
          },
        ),
      );

      final fieldFinder = find.byType(TextField);

      await tester.tap(fieldFinder);
      await tester.pump();

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Desktop draft',
          selection: TextSelection.collapsed(offset: 13),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(sendCalls, 1);
    },
  );

  testWidgets('mobile enter does not send and the draft remains multiline', (
    tester,
  ) async {
    var sendCalls = 0;

    await tester.pumpWidget(
      buildComposerApp(
        platform: TargetPlatform.android,
        contract: composerContract(),
        onSend: () async {
          sendCalls += 1;
        },
      ),
    );

    final fieldFinder = find.byType(TextField);

    await tester.tap(fieldFinder);
    await tester.pump();
    await tester.enterText(fieldFinder, 'Mobile draft');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(sendCalls, 0);
    expect(
      tester.widget<TextField>(fieldFinder).textInputAction,
      TextInputAction.newline,
    );

    await tester.enterText(fieldFinder, 'Mobile draft\nSecond line');
    await tester.pump();

    expect(
      tester.widget<TextField>(fieldFinder).controller?.text,
      'Mobile draft\nSecond line',
    );
  });

  testWidgets('keeps desktop focus and the send affordance stable while busy', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildComposerApp(
        platform: TargetPlatform.macOS,
        contract: composerContract(draftText: 'Desktop draft'),
      ),
    );

    final fieldFinder = find.byType(TextField);

    await tester.tap(fieldFinder);
    await tester.pump();

    expect(editableTextFocusNode(tester).hasFocus, isTrue);
    expect(find.byKey(const ValueKey('send')), findsOneWidget);

    await tester.pumpWidget(
      buildComposerApp(
        platform: TargetPlatform.macOS,
        contract: composerContract(
          draftText: 'Desktop draft',
          isSendActionEnabled: false,
        ),
      ),
    );
    await tester.pump();

    expect(editableTextFocusNode(tester).hasFocus, isTrue);
    expect(find.byKey(const ValueKey('send')), findsOneWidget);
    expect(find.byKey(const ValueKey('stop')), findsNothing);
  });

  testWidgets(
    'does not locally re-enable send when the screen contract disallows sending',
    (tester) async {
      await tester.pumpWidget(
        buildComposerApp(
          contract: composerContract(isSendActionEnabled: false),
        ),
      );

      final fieldFinder = find.byType(TextField);
      await tester.enterText(fieldFinder, 'Typed while blocked');
      await tester.pump();

      final sendButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('send')),
      );

      expect(sendButton.onPressed, isNull);
    },
  );

  testWidgets('enables send for an image-only draft', (tester) async {
    await tester.pumpWidget(
      buildComposerApp(
        contract: ChatComposerContract(
          draft: const ChatComposerDraft(
            text: '[Image #1]',
            imageAttachments: <ChatComposerImageAttachment>[
              ChatComposerImageAttachment(
                imageUrl: 'data:image/png;base64,cmVmZXJlbmNl',
                displayName: 'reference.png',
                placeholder: '[Image #1]',
              ),
            ],
          ).normalized(),
          isSendActionEnabled: true,
          allowsImageAttachment: true,
          placeholder: 'Message Codex',
        ),
      ),
    );

    final sendButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('send')),
    );

    expect(sendButton.onPressed, isNotNull);
  });

  testWidgets('uses a compact chat-style input shell', (tester) async {
    await tester.pumpWidget(buildComposerApp(contract: composerContract()));

    final field = tester.widget<TextField>(find.byType(TextField));
    final sendSize = tester.getSize(find.byKey(const ValueKey('send')));

    expect(field.decoration?.isCollapsed, isTrue);
    expect(
      field.decoration?.contentPadding,
      const EdgeInsets.symmetric(vertical: 4),
    );
    expect(sendSize, const Size(36, 36));
  });

  testWidgets('tapping outside the composer input dismisses focus', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildComposerApp(
        contract: composerContract(),
        includeOutsideTapTarget: true,
      ),
    );

    final fieldFinder = find.byType(TextField);

    await tester.tap(fieldFinder);
    await tester.pump();

    expect(editableTextFocusNode(tester).hasFocus, isTrue);

    await tester.tapAt(const Offset(24, 24));
    await tester.pump();

    expect(editableTextFocusNode(tester).hasFocus, isFalse);
  });

  testWidgets('send dismisses composer focus on mobile', (tester) async {
    await tester.pumpWidget(
      buildComposerApp(
        platform: TargetPlatform.android,
        contract: composerContract(),
      ),
    );

    final fieldFinder = find.byType(TextField);

    await tester.tap(fieldFinder);
    await tester.pump();
    await tester.enterText(fieldFinder, 'Mobile draft');
    await tester.pump();

    expect(editableTextFocusNode(tester).hasFocus, isTrue);

    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pump();

    expect(editableTextFocusNode(tester).hasFocus, isFalse);
  });
}
