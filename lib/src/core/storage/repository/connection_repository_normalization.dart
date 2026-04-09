import 'package:pocket_relay/src/core/models/connection_models.dart';

SavedWorkspace normalizeWorkspace(SavedWorkspace workspace) {
  final normalizedWorkspaceId = requireConnectionId(workspace.id);
  final profile = workspace.profile;
  final normalizedSystemId = profile.systemId?.trim();
  return SavedWorkspace(
    id: normalizedWorkspaceId,
    profile: profile.copyWith(
      label: profile.label.trim().isEmpty ? 'Workspace' : profile.label.trim(),
      systemId: normalizedSystemId == null || normalizedSystemId.isEmpty
          ? null
          : normalizedSystemId,
      workspaceDir: profile.workspaceDir.trim(),
      codexPath: profile.codexPath.trim(),
      model: profile.model.trim(),
    ),
  );
}

SavedConnection normalizeConnection(SavedConnection connection) {
  final normalizedConnectionId = requireConnectionId(connection.id);
  final normalizedLabel = connection.profile.label.trim();
  return SavedConnection(
    id: normalizedConnectionId,
    profile: connection.profile.copyWith(
      label: normalizedLabel.isEmpty ? 'Workspace' : normalizedLabel,
      host: connection.profile.host.trim(),
      username: connection.profile.username.trim(),
      workspaceDir: connection.profile.workspaceDir.trim(),
      codexPath: connection.profile.codexPath.trim(),
      hostFingerprint: connection.profile.hostFingerprint.trim(),
      model: connection.profile.model.trim(),
    ),
    secrets: connection.secrets,
  );
}

SavedSystem normalizeSystem(SavedSystem system) {
  final normalizedSystemId = requireSystemId(system.id);
  final profile = system.profile;
  return SavedSystem(
    id: normalizedSystemId,
    profile: profile.copyWith(
      label: profile.label.trim(),
      host: profile.host.trim(),
      username: profile.username.trim(),
      hostFingerprint: profile.hostFingerprint.trim(),
    ),
    secrets: system.secrets.copyWith(
      password: system.secrets.password,
      privateKeyPem: system.secrets.privateKeyPem,
      privateKeyPassphrase: system.secrets.privateKeyPassphrase,
    ),
  );
}

bool shouldPersistSystem(SystemProfile profile, ConnectionSecrets secrets) {
  final defaults = SystemProfile.defaults();
  return profile.host.trim().isNotEmpty ||
      profile.username.trim().isNotEmpty ||
      profile.hostFingerprint.trim().isNotEmpty ||
      profile.port != defaults.port ||
      profile.authMode != defaults.authMode ||
      !connectionSecretsEqual(secrets, const ConnectionSecrets());
}

SavedSystem? matchingSystem(
  Iterable<SavedSystem> systems, {
  required SystemProfile profile,
  required ConnectionSecrets secrets,
}) {
  for (final system in systems) {
    if (sameSystemIdentity(system.profile, profile) &&
        connectionSecretsEqual(system.secrets, secrets)) {
      return system;
    }
  }
  return null;
}

bool sameSystemIdentity(SystemProfile left, SystemProfile right) {
  return left.host.trim().toLowerCase() == right.host.trim().toLowerCase() &&
      left.port == right.port &&
      left.username.trim() == right.username.trim() &&
      left.authMode == right.authMode;
}

bool sameSystemHostIdentity(SystemProfile left, SystemProfile right) {
  final leftKey = _systemHostIdentityKey(left);
  final rightKey = _systemHostIdentityKey(right);
  return leftKey != null && leftKey == rightKey;
}

SystemProfile normalizeSystemFingerprintFromHostIdentity(
  SystemProfile profile,
  Iterable<SavedSystem> systems,
) {
  if (profile.hostFingerprint.trim().isNotEmpty) {
    return profile;
  }
  final sharedFingerprint = _sharedFingerprintForHost(systems, profile);
  if (sharedFingerprint.isEmpty) {
    return profile;
  }
  return profile.copyWith(hostFingerprint: sharedFingerprint);
}

SystemProfile mergeSystemFingerprint(
  SystemProfile existing,
  SystemProfile incoming,
) {
  final incomingFingerprint = incoming.hostFingerprint.trim();
  if (incomingFingerprint.isEmpty ||
      existing.hostFingerprint.trim() == incomingFingerprint) {
    return existing;
  }
  return existing.copyWith(hostFingerprint: incomingFingerprint);
}

int workspaceCountForSystem(
  Iterable<SavedWorkspace> workspaces,
  String systemId,
) {
  var count = 0;
  for (final workspace in workspaces) {
    if (workspace.profile.systemId == systemId) {
      count += 1;
    }
  }
  return count;
}

String requireSystemId(String systemId) {
  final normalizedSystemId = systemId.trim();
  if (normalizedSystemId.isEmpty) {
    throw ArgumentError.value(
      systemId,
      'systemId',
      'System id must not be empty.',
    );
  }
  return normalizedSystemId;
}

String requireConnectionId(String connectionId) {
  final normalizedConnectionId = connectionId.trim();
  if (normalizedConnectionId.isEmpty) {
    throw ArgumentError.value(
      connectionId,
      'connectionId',
      'Connection id must not be empty.',
    );
  }
  return normalizedConnectionId;
}

String? _systemHostIdentityKey(SystemProfile profile) {
  final normalizedHost = profile.host.trim().toLowerCase();
  if (normalizedHost.isEmpty) {
    return null;
  }
  return '$normalizedHost:${profile.port}';
}

String _sharedFingerprintForHost(
  Iterable<SavedSystem> systems,
  SystemProfile profile,
) {
  for (final system in systems) {
    if (!sameSystemHostIdentity(system.profile, profile)) {
      continue;
    }
    final fingerprint = system.profile.hostFingerprint.trim();
    if (fingerprint.isNotEmpty) {
      return fingerprint;
    }
  }
  return '';
}
