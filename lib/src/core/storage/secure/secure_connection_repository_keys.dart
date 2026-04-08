const legacyCatalogIndexKey = 'pocket_relay.connections.index';
const legacyCatalogSchemaVersion = 1;
const catalogPreferencesMigrationKey =
    'pocket_relay.connections_async_migration_complete';
const legacySingletonProfileKey = 'pocket_relay.profile';
const legacySingletonPasswordKey = 'pocket_relay.secret.password';
const legacySingletonPrivateKeyKey = 'pocket_relay.secret.private_key';
const legacySingletonPrivateKeyPassphraseKey =
    'pocket_relay.secret.private_key_passphrase';
const legacyProfileKeyPrefix = 'pocket_relay.connection.';
const legacyProfileKeySuffix = '.profile';
const legacySecretKeyPrefix = 'pocket_relay.connection.';
const legacyPasswordKeySuffix = '.secret.password';
const legacyPrivateKeyKeySuffix = '.secret.private_key';
const legacyPrivateKeyPassphraseKeySuffix = '.secret.private_key_passphrase';
const workspaceCatalogIndexKey = 'pocket_relay.workspaces.index';
const workspaceCatalogSchemaVersion = 1;
const workspaceProfileKeyPrefix = 'pocket_relay.workspace.';
const workspaceProfileKeySuffix = '.profile';
const systemCatalogIndexKey = 'pocket_relay.systems.index';
const systemCatalogSchemaVersion = 1;
const systemProfileKeyPrefix = 'pocket_relay.system.';
const systemProfileKeySuffix = '.profile';
const systemSecretKeyPrefix = 'pocket_relay.system.';
const systemPasswordKeySuffix = '.secret.password';
const systemPrivateKeyKeySuffix = '.secret.private_key';
const systemPrivateKeyPassphraseKeySuffix = '.secret.private_key_passphrase';

String workspaceProfileKeyForWorkspace(String workspaceId) {
  return '$workspaceProfileKeyPrefix$workspaceId$workspaceProfileKeySuffix';
}

String systemProfileKeyForSystem(String systemId) {
  return '$systemProfileKeyPrefix$systemId$systemProfileKeySuffix';
}

String systemPasswordKeyForSystem(String systemId) {
  return '$systemSecretKeyPrefix$systemId$systemPasswordKeySuffix';
}

String systemPrivateKeyKeyForSystem(String systemId) {
  return '$systemSecretKeyPrefix$systemId$systemPrivateKeyKeySuffix';
}

String systemPrivateKeyPassphraseKeyForSystem(String systemId) {
  return '$systemSecretKeyPrefix$systemId$systemPrivateKeyPassphraseKeySuffix';
}

String profileKeyForConnection(String connectionId) {
  return '$legacyProfileKeyPrefix$connectionId$legacyProfileKeySuffix';
}

String passwordKeyForConnection(String connectionId) {
  return '$legacySecretKeyPrefix$connectionId$legacyPasswordKeySuffix';
}

String privateKeyKeyForConnection(String connectionId) {
  return '$legacySecretKeyPrefix$connectionId$legacyPrivateKeyKeySuffix';
}

String privateKeyPassphraseKeyForConnection(String connectionId) {
  return '$legacySecretKeyPrefix$connectionId$legacyPrivateKeyPassphraseKeySuffix';
}
