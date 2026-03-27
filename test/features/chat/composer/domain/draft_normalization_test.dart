import '../support/composer_test_support.dart';

void main() {
  test('image text elements use UTF-8 byte offsets', () {
    final draft = const ChatComposerDraft(
      text: 'é [Image #1]',
      imageAttachments: <ChatComposerImageAttachment>[
        ChatComposerImageAttachment(
          imageUrl: 'data:image/png;base64,cmVmZXJlbmNl',
          displayName: 'reference.png',
          placeholder: '[Image #1]',
        ),
      ],
    ).normalized();

    expect(draft.textElements, const <ChatComposerTextElement>[
      ChatComposerTextElement(start: 3, end: 13, placeholder: '[Image #1]'),
    ]);
  });

  test('normalizes image placeholders by text order and renumbers them', () {
    final draft = const ChatComposerDraft(
      text: '[Image #2] then [Image #1]',
      imageAttachments: <ChatComposerImageAttachment>[
        ChatComposerImageAttachment(
          imageUrl: 'data:image/png;base64,c2Vjb25k',
          displayName: 'second.png',
          placeholder: '[Image #1]',
        ),
        ChatComposerImageAttachment(
          imageUrl: 'data:image/png;base64,Zmlyc3Q=',
          displayName: 'first.png',
          placeholder: '[Image #2]',
        ),
      ],
    ).normalized();

    expect(draft.text, '[Image #1] then [Image #2]');
    expect(draft.imageAttachments, const <ChatComposerImageAttachment>[
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
    ]);
  });

  test(
    'insertImageAttachment preserves placeholder order when inserting before an existing image',
    () {
      final insertion =
          const ChatComposerDraft(
            text: 'Before [Image #1]',
            imageAttachments: <ChatComposerImageAttachment>[
              ChatComposerImageAttachment(
                imageUrl: 'data:image/png;base64,ZXhpc3Rpbmc=',
                displayName: 'existing.png',
                placeholder: '[Image #1]',
              ),
            ],
          ).insertImageAttachment(
            attachment: const ChatComposerImageAttachment(
              imageUrl: 'data:image/png;base64,ZWFybGllcg==',
              displayName: 'earlier.png',
            ),
            selectionStart: 0,
            selectionEnd: 0,
          );

      expect(insertion.draft.text, '[Image #1]Before [Image #2]');
      expect(
        insertion.draft.imageAttachments,
        const <ChatComposerImageAttachment>[
          ChatComposerImageAttachment(
            imageUrl: 'data:image/png;base64,ZWFybGllcg==',
            displayName: 'earlier.png',
            placeholder: '[Image #1]',
          ),
          ChatComposerImageAttachment(
            imageUrl: 'data:image/png;base64,ZXhpc3Rpbmc=',
            displayName: 'existing.png',
            placeholder: '[Image #2]',
          ),
        ],
      );
    },
  );

  test(
    'insertImageAttachment avoids reusing a user-typed placeholder token',
    () {
      final insertion =
          const ChatComposerDraft(
            text: 'Manual [Image #1] token ',
          ).insertImageAttachment(
            attachment: const ChatComposerImageAttachment(
              imageUrl: 'data:image/png;base64,cmVmZXJlbmNl',
              displayName: 'reference.png',
            ),
            selectionStart: 24,
            selectionEnd: 24,
          );

      expect(insertion.draft.text, 'Manual [Image #1] token [Image #2]');
      expect(
        insertion.draft.imageAttachments,
        const <ChatComposerImageAttachment>[
          ChatComposerImageAttachment(
            imageUrl: 'data:image/png;base64,cmVmZXJlbmNl',
            displayName: 'reference.png',
            placeholder: '[Image #2]',
          ),
        ],
      );
      expect(insertion.draft.textElements, const <ChatComposerTextElement>[
        ChatComposerTextElement(start: 24, end: 34, placeholder: '[Image #2]'),
      ]);
    },
  );
}
