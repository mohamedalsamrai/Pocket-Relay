import 'dart:convert';

import 'package:pocket_relay/src/core/models/connection_models.dart';

import 'secure_connection_repository_keys.dart';
import 'secure_connection_repository_state.dart';

Future<void> persistWorkspaceProfile(
  SecureConnectionRepositoryState state, {
  required String workspaceId,
  required WorkspaceProfile profile,
}) async {
  await state.preferences.setString(
    workspaceProfileKeyForWorkspace(workspaceId),
    jsonEncode(profile.toJson()),
  );
}

Future<void> persistSystemProfile(
  SecureConnectionRepositoryState state, {
  required String systemId,
  required SystemProfile profile,
}) async {
  await state.preferences.setString(
    systemProfileKeyForSystem(systemId),
    jsonEncode(profile.toJson()),
  );
}
