import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences/util/legacy_to_async_migration_util.dart';

class SharedPreferencesAsyncMigrationGate {
  const SharedPreferencesAsyncMigrationGate({
    required this.migrationCompletedKey,
  });

  final String migrationCompletedKey;

  Future<void> ensureReady() async {
    final legacyPreferences = await SharedPreferences.getInstance();
    await migrateLegacySharedPreferencesToSharedPreferencesAsyncIfNecessary(
      legacySharedPreferencesInstance: legacyPreferences,
      sharedPreferencesAsyncOptions: const SharedPreferencesOptions(),
      migrationCompletedKey: migrationCompletedKey,
    );
  }
}
