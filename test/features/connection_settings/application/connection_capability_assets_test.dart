import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_model_catalog_store.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_capability_assets.dart';

void main() {
  test(
    'store-backed assets save and load connection-scoped catalogs',
    () async {
      final assets = StoreBackedConnectionCapabilityAssets(
        connectionRepository: MemoryCodexConnectionRepository(),
        modelCatalogStore: MemoryConnectionModelCatalogStore(),
      );
      final catalog = ConnectionModelCatalog(
        connectionId: 'conn_secondary',
        fetchedAt: DateTime.utc(2026, 3, 22, 12),
        models: const <ConnectionAvailableModel>[
          ConnectionAvailableModel(
            id: 'preset_gpt_54',
            model: 'gpt-5.4',
            displayName: 'GPT-5.4',
            description: 'Latest frontier agentic coding model.',
            hidden: false,
            supportedReasoningEfforts:
                <ConnectionAvailableModelReasoningEffortOption>[
                  ConnectionAvailableModelReasoningEffortOption(
                    reasoningEffort: CodexReasoningEffort.medium,
                    description: 'Balanced default for general work.',
                  ),
                ],
            defaultReasoningEffort: CodexReasoningEffort.medium,
            inputModalities: <String>['text'],
            supportsPersonality: true,
            isDefault: true,
          ),
        ],
      );

      await assets.saveConnectionModelCatalog(catalog);

      expect(
        await assets.loadConnectionModelCatalog('conn_secondary'),
        catalog,
      );
    },
  );

  test('store-backed assets delete connection-scoped catalogs', () async {
    final assets = StoreBackedConnectionCapabilityAssets(
      connectionRepository: MemoryCodexConnectionRepository(),
      modelCatalogStore: MemoryConnectionModelCatalogStore(
        initialCatalogs: <ConnectionModelCatalog>[
          ConnectionModelCatalog(
            connectionId: 'conn_secondary',
            fetchedAt: DateTime.utc(2026, 3, 22, 12),
            models: const <ConnectionAvailableModel>[],
          ),
        ],
      ),
    );

    await assets.deleteConnectionModelCatalog('conn_secondary');

    expect(await assets.loadConnectionModelCatalog('conn_secondary'), isNull);
  });

  test('store-backed assets save and load the last-known catalog', () async {
    final assets = StoreBackedConnectionCapabilityAssets(
      connectionRepository: MemoryCodexConnectionRepository(),
      modelCatalogStore: MemoryConnectionModelCatalogStore(),
    );
    final catalog = ConnectionModelCatalog(
      connectionId: 'conn_primary',
      fetchedAt: DateTime.utc(2026, 3, 22, 12, 30),
      models: const <ConnectionAvailableModel>[
        ConnectionAvailableModel(
          id: 'preset_gpt_54',
          model: 'gpt-5.4',
          displayName: 'GPT-5.4',
          description: 'Latest frontier agentic coding model.',
          hidden: false,
          supportedReasoningEfforts:
              <ConnectionAvailableModelReasoningEffortOption>[
                ConnectionAvailableModelReasoningEffortOption(
                  reasoningEffort: CodexReasoningEffort.medium,
                  description: 'Balanced default for general work.',
                ),
              ],
          defaultReasoningEffort: CodexReasoningEffort.medium,
          inputModalities: <String>['text'],
          supportsPersonality: true,
          isDefault: true,
        ),
      ],
    );

    await assets.saveLastKnownConnectionModelCatalog(catalog);

    expect(await assets.loadLastKnownConnectionModelCatalog(), catalog);
  });

  test(
    'store-backed assets derive reusable templates from saved systems',
    () async {
      final assets = StoreBackedConnectionCapabilityAssets(
        connectionRepository: MemoryCodexConnectionRepository(
          initialSystems: <SavedSystem>[
            SavedSystem(
              id: 'system_primary',
              profile: const SystemProfile(
                label: 'Build Box',
                host: 'devbox.local',
                port: 2200,
                username: 'alice',
                authMode: AuthMode.privateKey,
                hostFingerprint: '11:22:33:44',
              ),
              secrets: const ConnectionSecrets(
                privateKeyPem:
                    '-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----',
              ),
            ),
          ],
        ),
        modelCatalogStore: MemoryConnectionModelCatalogStore(),
      );

      final templates = await assets.loadReusableSystemTemplates();

      expect(templates, hasLength(1));
      expect(templates.single.id, 'system_primary');
      expect(templates.single.profile.label, 'Build Box');
      expect(templates.single.profile.host, 'devbox.local');
    },
  );
}
