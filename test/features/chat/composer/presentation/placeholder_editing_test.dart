import '../support/composer_test_support.dart';

void main() {
  testWidgets(
    'backspace deletes an inline image placeholder atomically and renumbers survivors',
    (tester) async {
      ChatComposerDraft? latestDraft;

      await tester.pumpWidget(
        buildComposerApp(
          platform: TargetPlatform.macOS,
          contract: ChatComposerContract(
            draft: const ChatComposerDraft(
              text: 'A[Image #1]B[Image #2]C',
              imageAttachments: <ChatComposerImageAttachment>[
                ChatComposerImageAttachment(
                  imageUrl: 'data:image/png;base64,Zmlyc3Q=',
                  displayName: 'first.png',
                  placeholder: '[Image #1]',
                ),
                ChatComposerImageAttachment(
                  imageUrl: 'data:image/png;base64,c2Vjb25k',
                  displayName: 'second.png',
                  placeholder: '[Image #2]',
                ),
              ],
            ).normalized(),
            isSendActionEnabled: true,
            allowsImageAttachment: true,
            placeholder: 'Message Codex',
          ),
          onChanged: (draft) {
            latestDraft = draft;
          },
        ),
      );

      final fieldFinder = find.byType(TextField);
      await tester.tap(fieldFinder);
      await tester.pump();

      final controller = tester.widget<TextField>(fieldFinder).controller!;
      controller.selection = const TextSelection.collapsed(offset: 11);
      await tester.pump();

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'A[Image #1B[Image #2]C',
          selection: TextSelection.collapsed(offset: 10),
        ),
      );
      await tester.pump();

      expect(controller.text, 'AB[Image #1]C');
      expect(latestDraft?.text, 'AB[Image #1]C');
      expect(latestDraft?.imageAttachments, const <ChatComposerImageAttachment>[
        ChatComposerImageAttachment(
          imageUrl: 'data:image/png;base64,c2Vjb25k',
          displayName: 'second.png',
          placeholder: '[Image #1]',
        ),
      ]);
    },
  );

  testWidgets(
    'typing inside an inline image placeholder moves the text insertion outside the placeholder',
    (tester) async {
      ChatComposerDraft? latestDraft;

      await tester.pumpWidget(
        buildComposerApp(
          platform: TargetPlatform.macOS,
          contract: ChatComposerContract(
            draft: const ChatComposerDraft(
              text: 'A[Image #1]B',
              imageAttachments: <ChatComposerImageAttachment>[
                ChatComposerImageAttachment(
                  imageUrl: 'data:image/png;base64,Zmlyc3Q=',
                  displayName: 'first.png',
                  placeholder: '[Image #1]',
                ),
              ],
            ).normalized(),
            isSendActionEnabled: true,
            allowsImageAttachment: true,
            placeholder: 'Message Codex',
          ),
          onChanged: (draft) {
            latestDraft = draft;
          },
        ),
      );

      final fieldFinder = find.byType(TextField);
      await tester.tap(fieldFinder);
      await tester.pump();

      final controller = tester.widget<TextField>(fieldFinder).controller!;
      controller.selection = const TextSelection.collapsed(offset: 4);
      await tester.pump();

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'A[Ixmage #1]B',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      await tester.pump();

      expect(controller.text, 'A[Image #1]xB');
      expect(latestDraft?.text, 'A[Image #1]xB');
      expect(latestDraft?.imageAttachments, const <ChatComposerImageAttachment>[
        ChatComposerImageAttachment(
          imageUrl: 'data:image/png;base64,Zmlyc3Q=',
          displayName: 'first.png',
          placeholder: '[Image #1]',
        ),
      ]);
    },
  );
}
