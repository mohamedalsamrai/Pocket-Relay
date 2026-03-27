import 'client_test_support.dart';

void main() {
  test('listModels sends model/list and decodes model metadata', () async {
    late FakeCodexAppServerProcess process;
    process = FakeCodexAppServerProcess(
      onClientMessage: (message) {
        switch (message['method']) {
          case 'initialize':
            process.sendStdout(<String, Object?>{
              'id': message['id'],
              'result': <String, Object?>{'userAgent': 'codex-app-server-test'},
            });
          case 'model/list':
            process.sendStdout(<String, Object?>{
              'id': message['id'],
              'result': <String, Object?>{
                'data': <Object>[
                  <String, Object?>{
                    'id': 'preset_gpt_54',
                    'model': 'gpt-5.4',
                    'upgrade': 'gpt-5.5',
                    'upgradeInfo': <String, Object?>{
                      'model': 'gpt-5.5',
                      'upgradeCopy': 'Upgrade available',
                      'modelLink': 'https://example.com/models/gpt-5.5',
                      'migrationMarkdown': 'Use the newer model.',
                    },
                    'availabilityNux': <String, Object?>{
                      'message': 'Enable billing to access this model.',
                    },
                    'displayName': 'GPT-5.4',
                    'description': 'Latest frontier agentic coding model.',
                    'hidden': false,
                    'supportedReasoningEfforts': <Object>[
                      <String, Object?>{
                        'reasoningEffort': 'medium',
                        'description': 'Balanced default for general work.',
                      },
                      <String, Object?>{
                        'reasoningEffort': 'high',
                        'description': 'Spend more reasoning on harder tasks.',
                      },
                    ],
                    'defaultReasoningEffort': 'medium',
                    'inputModalities': <Object>['text'],
                    'supportsPersonality': true,
                    'isDefault': true,
                  },
                ],
                'nextCursor': 'cursor_2',
              },
            });
        }
      },
    );

    final client = CodexAppServerClient(
      processLauncher:
          ({required profile, required secrets, required emitEvent}) async =>
              process,
    );

    await client.connect(
      profile: clientProfile(),
      secrets: const ConnectionSecrets(password: 'secret'),
    );

    final page = await client.listModels(
      cursor: 'cursor_1',
      limit: 25,
      includeHidden: true,
    );

    final request = process.writtenMessages.firstWhere(
      (message) => message['method'] == 'model/list',
    );
    expect(request['params'], <String, Object?>{
      'cursor': 'cursor_1',
      'limit': 25,
      'includeHidden': true,
    });
    expect(page.nextCursor, 'cursor_2');
    expect(page.models, hasLength(1));

    final model = page.models.single;
    expect(model.id, 'preset_gpt_54');
    expect(model.model, 'gpt-5.4');
    expect(model.displayName, 'GPT-5.4');
    expect(model.description, 'Latest frontier agentic coding model.');
    expect(model.hidden, isFalse);
    expect(model.defaultReasoningEffort, CodexReasoningEffort.medium);
    expect(model.supportsPersonality, isTrue);
    expect(model.isDefault, isTrue);
    expect(model.inputModalities, <String>['text']);
    expect(model.upgrade, 'gpt-5.5');
    expect(model.upgradeInfo, isNotNull);
    expect(model.upgradeInfo!.model, 'gpt-5.5');
    expect(
      model.availabilityNuxMessage,
      'Enable billing to access this model.',
    );
    expect(
      model.supportedReasoningEfforts
          .map((option) => option.reasoningEffort)
          .toList(growable: false),
      <CodexReasoningEffort>[
        CodexReasoningEffort.medium,
        CodexReasoningEffort.high,
      ],
    );

    await client.disconnect();
  });

  test(
    'listModels accepts snake_case model metadata and normalizes modalities',
    () async {
      late FakeCodexAppServerProcess process;
      process = FakeCodexAppServerProcess(
        onClientMessage: (message) {
          switch (message['method']) {
            case 'initialize':
              process.sendStdout(<String, Object?>{
                'id': message['id'],
                'result': <String, Object?>{
                  'userAgent': 'codex-app-server-test',
                },
              });
            case 'model/list':
              process.sendStdout(<String, Object?>{
                'id': message['id'],
                'result': <String, Object?>{
                  'data': <Object>[
                    <String, Object?>{
                      'id': 'preset_vision_snake',
                      'model': 'gpt-vision',
                      'display_name': 'GPT Vision',
                      'description': 'Vision-capable model.',
                      'hidden': true,
                      'supported_reasoning_efforts': <Object>[
                        <String, Object?>{
                          'reasoning_effort': 'high',
                          'description': 'High effort.',
                        },
                      ],
                      'default_reasoning_effort': 'high',
                      'input_modalities': <Object>['TEXT', 'Image', 'text'],
                      'supports_personality': false,
                      'is_default': false,
                      'upgrade_info': <String, Object?>{
                        'model': 'gpt-vision-2',
                        'upgradeCopy': 'Upgrade available',
                      },
                      'availability_nux': <String, Object?>{
                        'message': 'Request access for vision.',
                      },
                    },
                  ],
                },
              });
          }
        },
      );

      final client = CodexAppServerClient(
        processLauncher:
            ({required profile, required secrets, required emitEvent}) async =>
                process,
      );

      await client.connect(
        profile: clientProfile(),
        secrets: const ConnectionSecrets(password: 'secret'),
      );

      final page = await client.listModels();

      expect(page.models, hasLength(1));
      final model = page.models.single;
      expect(model.displayName, 'GPT Vision');
      expect(model.hidden, isTrue);
      expect(model.defaultReasoningEffort, CodexReasoningEffort.high);
      expect(model.inputModalities, <String>['text', 'image']);
      expect(model.supportsImageInput, isTrue);
      expect(
        model.supportedReasoningEfforts,
        <CodexAppServerReasoningEffortOption>[
          const CodexAppServerReasoningEffortOption(
            reasoningEffort: CodexReasoningEffort.high,
            description: 'High effort.',
          ),
        ],
      );
      expect(model.upgradeInfo?.model, 'gpt-vision-2');
      expect(model.availabilityNuxMessage, 'Request access for vision.');

      await client.disconnect();
    },
  );
}
