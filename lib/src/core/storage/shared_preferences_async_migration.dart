import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences/util/legacy_to_async_migration_util.dart';

Future<void> ensureSharedPreferencesAsyncReady({
  required String migrationCompletedKey,
}) async {
  final legacyPreferences = await SharedPreferences.getInstance();
  await migrateLegacySharedPreferencesToSharedPreferencesAsyncIfNecessary(
    legacySharedPreferencesInstance: legacyPreferences,
    sharedPreferencesAsyncOptions: const SharedPreferencesOptions(),
    migrationCompletedKey: migrationCompletedKey,
  );
}
