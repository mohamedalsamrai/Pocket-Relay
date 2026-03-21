import 'package:flutter/material.dart';
import 'package:pocket_relay/src/app.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_conversation_history_store.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_composer.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/empty_state.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/assistant_message_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/error_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/reasoning_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/status_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/user_message_card.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_host.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_sheet.dart';
import 'package:pocket_relay/widgetbook/support/fake_codex_app_server_client.dart';
import 'package:pocket_relay/widgetbook/support/widgetbook_fixtures.dart';
import 'package:pocket_relay/widgetbook/support/widgetbook_story_frame.dart';
import 'package:widgetbook/widgetbook.dart';

List<WidgetbookNode> buildPocketRelayWidgetbookCatalog() {
  return <WidgetbookNode>[
    WidgetbookCategory(
      name: 'Chat',
      children: <WidgetbookNode>[
        WidgetbookFolder(
          name: 'Cards',
          children: <WidgetbookNode>[
            WidgetbookComponent(
              name: 'Assistant Message',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Preview',
                  builder: (context) {
                    final body = context.knobs.string(
                      label: 'Body',
                      initialValue: WidgetbookFixtures.assistantMessageMarkdown,
                    );
                    final isRunning = context.knobs.boolean(
                      label: 'Streaming',
                      initialValue: false,
                    );
                    return WidgetbookStoryFrame.card(
                      child: AssistantMessageCard(
                        block: WidgetbookFixtures.assistantMessage(
                          body: body,
                          isRunning: isRunning,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Reasoning',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Preview',
                  builder: (context) {
                    final isRunning = context.knobs.boolean(
                      label: 'Running',
                      initialValue: true,
                    );
                    return WidgetbookStoryFrame.card(
                      child: ReasoningCard(
                        block: WidgetbookFixtures.reasoningBlock(
                          isRunning: isRunning,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'User Message',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Preview',
                  builder: (context) {
                    final localEcho = context.knobs.boolean(
                      label: 'Local echo',
                      initialValue: false,
                    );
                    return WidgetbookStoryFrame.card(
                      alignment: Alignment.centerRight,
                      child: UserMessageCard(
                        block: WidgetbookFixtures.userMessage(
                          deliveryState: localEcho
                              ? CodexUserMessageDeliveryState.localEcho
                              : CodexUserMessageDeliveryState.sent,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Status',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Preview',
                  builder: (context) {
                    return WidgetbookStoryFrame.card(
                      child: StatusCard(
                        block: WidgetbookFixtures.statusBlock(),
                      ),
                    );
                  },
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Error',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Preview',
                  builder: (context) {
                    return WidgetbookStoryFrame.card(
                      child: ErrorCard(block: WidgetbookFixtures.errorBlock()),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        WidgetbookComponent(
          name: 'Composer',
          useCases: <WidgetbookUseCase>[
            WidgetbookUseCase(
              name: 'Mobile',
              builder: (context) {
                final draftText = context.knobs.string(
                  label: 'Draft',
                  initialValue: 'Summarize the latest transcript changes.',
                );
                return WidgetbookStoryFrame.card(
                  maxWidth: 720,
                  child: ChatComposer(
                    platformBehavior: WidgetbookFixtures.mobileBehavior,
                    contract: ChatComposerContract(
                      draftText: draftText,
                      isSendActionEnabled: draftText.trim().isNotEmpty,
                      placeholder: 'Ask Codex to continue',
                    ),
                    onChanged: (_) {},
                    onSend: () async {},
                  ),
                );
              },
            ),
            WidgetbookUseCase(
              name: 'Desktop',
              builder: (context) {
                final draftText = context.knobs.string(
                  label: 'Draft',
                  initialValue:
                      'Run the failing test file and explain the regression.',
                );
                return WidgetbookStoryFrame.card(
                  maxWidth: 920,
                  child: ChatComposer(
                    platformBehavior: WidgetbookFixtures.desktopBehavior,
                    contract: ChatComposerContract(
                      draftText: draftText,
                      isSendActionEnabled: draftText.trim().isNotEmpty,
                      placeholder: 'Message Pocket Relay',
                    ),
                    onChanged: (_) {},
                    onSend: () async {},
                  ),
                );
              },
            ),
          ],
        ),
        WidgetbookComponent(
          name: 'Empty State',
          useCases: <WidgetbookUseCase>[
            WidgetbookUseCase(
              name: 'Mobile First Run',
              builder: (context) {
                return WidgetbookStoryFrame.fill(
                  child: EmptyState(
                    isConfigured: false,
                    connectionMode: ConnectionMode.remote,
                    platformBehavior: WidgetbookFixtures.mobileBehavior,
                    onConfigure: () {},
                  ),
                );
              },
            ),
            WidgetbookUseCase(
              name: 'Desktop Configured',
              builder: (context) {
                return WidgetbookStoryFrame.fill(
                  child: EmptyState(
                    isConfigured: true,
                    connectionMode: ConnectionMode.local,
                    platformBehavior: WidgetbookFixtures.desktopBehavior,
                    onConfigure: () {},
                    onSelectConnectionMode: (_) {},
                  ),
                );
              },
            ),
          ],
        ),
      ],
    ),
    WidgetbookCategory(
      name: 'Settings',
      children: <WidgetbookNode>[
        WidgetbookComponent(
          name: 'Connection Sheet',
          useCases: <WidgetbookUseCase>[
            WidgetbookUseCase(
              name: 'Remote Password',
              builder: (_) {
                return WidgetbookStoryFrame.fill(
                  maxWidth: 920,
                  child: ConnectionSettingsHost(
                    initialProfile: WidgetbookFixtures.remoteProfile,
                    initialSecrets: WidgetbookFixtures.passwordSecrets,
                    platformBehavior: WidgetbookFixtures.desktopBehavior,
                    onCancel: () {},
                    onSubmit: (_) {},
                    builder: (context, viewModel, actions) {
                      return ConnectionSheet(
                        viewModel: viewModel,
                        actions: actions,
                      );
                    },
                  ),
                );
              },
            ),
            WidgetbookUseCase(
              name: 'Local Workspace',
              builder: (_) {
                return WidgetbookStoryFrame.fill(
                  maxWidth: 920,
                  child: ConnectionSettingsHost(
                    initialProfile: WidgetbookFixtures.localProfile,
                    initialSecrets: const ConnectionSecrets(),
                    platformBehavior: WidgetbookFixtures.desktopBehavior,
                    onCancel: () {},
                    onSubmit: (_) {},
                    builder: (context, viewModel, actions) {
                      return ConnectionSheet(
                        viewModel: viewModel,
                        actions: actions,
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ],
    ),
    WidgetbookCategory(
      name: 'Shells',
      children: <WidgetbookNode>[
        WidgetbookComponent(
          name: 'Pocket Relay App',
          useCases: <WidgetbookUseCase>[
            WidgetbookUseCase(
              name: 'Mobile Active Lane',
              builder: (_) {
                return PocketRelayApp(
                  connectionRepository: MemoryCodexConnectionRepository.single(
                    savedProfile: WidgetbookFixtures.savedProfile,
                  ),
                  connectionConversationStateStore:
                      MemoryCodexConnectionConversationHistoryStore(),
                  appServerClient: WidgetbookFakeCodexAppServerClient(),
                  displayWakeLockController:
                      const NoopDisplayWakeLockController(),
                  platformPolicy: WidgetbookFixtures.mobilePolicy,
                );
              },
            ),
            WidgetbookUseCase(
              name: 'Desktop Active Lane',
              builder: (_) {
                return PocketRelayApp(
                  connectionRepository: MemoryCodexConnectionRepository.single(
                    savedProfile: WidgetbookFixtures.savedProfile,
                  ),
                  connectionConversationStateStore:
                      MemoryCodexConnectionConversationHistoryStore(),
                  appServerClient: WidgetbookFakeCodexAppServerClient(),
                  displayWakeLockController:
                      const NoopDisplayWakeLockController(),
                  platformPolicy: WidgetbookFixtures.desktopPolicy,
                );
              },
            ),
          ],
        ),
      ],
    ),
  ];
}
