import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

Future<List<String>> discoverStoredIds(
  SharedPreferencesAsync preferences, {
  required String prefix,
  required String suffix,
}) async {
  final keys = await preferences.getKeys();
  final ids = <String>[];
  for (final key in keys) {
    if (!key.startsWith(prefix) || !key.endsWith(suffix)) {
      continue;
    }
    final id = key.substring(prefix.length, key.length - suffix.length).trim();
    if (id.isNotEmpty) {
      ids.add(id);
    }
  }
  ids.sort();
  return ids;
}

Future<List<String>> loadOrderedIds(
  SharedPreferencesAsync preferences, {
  required String indexKey,
  required List<String> discoveredIds,
}) async {
  final rawIndex = await preferences.getString(indexKey);
  if (rawIndex == null || rawIndex.trim().isEmpty) {
    return discoveredIds;
  }

  final decoded = jsonDecode(rawIndex);
  if (decoded is! Map<String, dynamic>) {
    return discoveredIds;
  }
  final rawOrderedIds = decoded['orderedIds'];
  if (rawOrderedIds is! List) {
    return discoveredIds;
  }
  final orderedIds = <String>[
    for (final value in rawOrderedIds)
      if (value is String && value.trim().isNotEmpty) value.trim(),
  ];
  final orderedIdSet = orderedIds.toSet();
  final extraIds =
      discoveredIds.where((id) => !orderedIdSet.contains(id)).toList()..sort();
  return <String>[...orderedIds, ...extraIds];
}

Future<void> persistOrderedIds(
  SharedPreferencesAsync preferences, {
  required String indexKey,
  required int schemaVersion,
  required List<String> orderedIds,
}) async {
  await preferences.setString(
    indexKey,
    jsonEncode(<String, Object?>{
      'schemaVersion': schemaVersion,
      'orderedIds': orderedIds,
    }),
  );
}
