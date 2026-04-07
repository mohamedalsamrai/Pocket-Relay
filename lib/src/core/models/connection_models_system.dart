part of 'connection_models.dart';

class SystemProfile {
  const SystemProfile({
    this.label = '',
    required this.host,
    required this.port,
    required this.username,
    required this.authMode,
    required this.hostFingerprint,
  });

  final String label;
  final String host;
  final int port;
  final String username;
  final AuthMode authMode;
  final String hostFingerprint;

  factory SystemProfile.defaults() {
    return const SystemProfile(
      label: '',
      host: '',
      port: 22,
      username: '',
      authMode: AuthMode.password,
      hostFingerprint: '',
    );
  }

  bool get hasCustomLabel {
    final normalizedLabel = label.trim();
    if (normalizedLabel.isEmpty) {
      return false;
    }

    final identityLabel = _derivedIdentityLabel(usePlaceholder: false);
    return identityLabel.isEmpty || normalizedLabel != identityLabel;
  }

  String get displayLabel {
    final normalizedLabel = label.trim();
    if (normalizedLabel.isNotEmpty) {
      return normalizedLabel;
    }

    return _derivedIdentityLabel(usePlaceholder: true);
  }

  String get connectionIdentityLabel {
    return _derivedIdentityLabel(usePlaceholder: true);
  }

  String _derivedIdentityLabel({required bool usePlaceholder}) {
    final normalizedHost = host.trim();
    final normalizedUsername = username.trim();
    if (normalizedHost.isEmpty) {
      return usePlaceholder ? 'System not set' : '';
    }

    final hostWithPort = port == 22 ? normalizedHost : '$normalizedHost:$port';
    if (normalizedUsername.isEmpty) {
      return hostWithPort;
    }

    return '$normalizedUsername@$hostWithPort';
  }

  String? get remoteHostIdentityKey {
    final normalizedHost = host.trim().toLowerCase();
    if (normalizedHost.isEmpty) {
      return null;
    }

    return '$normalizedHost:$port';
  }

  SystemProfile copyWith({
    String? label,
    String? host,
    int? port,
    String? username,
    AuthMode? authMode,
    String? hostFingerprint,
  }) {
    return SystemProfile(
      label: label ?? this.label,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      authMode: authMode ?? this.authMode,
      hostFingerprint: hostFingerprint ?? this.hostFingerprint,
    );
  }

  factory SystemProfile.fromJson(Map<String, dynamic> json) {
    final defaults = SystemProfile.defaults();
    final host = json['host'] as String? ?? defaults.host;
    final port = (json['port'] as num?)?.toInt() ?? defaults.port;
    final username = json['username'] as String? ?? defaults.username;
    final normalizedLabel = (json['label'] as String?)?.trim();
    return SystemProfile(
      label: normalizedLabel == null || normalizedLabel.isEmpty
          ? SystemProfile(
              host: host,
              port: port,
              username: username,
              authMode: defaults.authMode,
              hostFingerprint: defaults.hostFingerprint,
            )._derivedIdentityLabel(usePlaceholder: false)
          : normalizedLabel,
      host: host,
      port: port,
      username: username,
      authMode: _authModeFromName(
        json['authMode'] as String?,
        fallback: defaults.authMode,
      ),
      hostFingerprint:
          json['hostFingerprint'] as String? ?? defaults.hostFingerprint,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'label': label,
      'host': host,
      'port': port,
      'username': username,
      'authMode': authMode.name,
      'hostFingerprint': hostFingerprint,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is SystemProfile &&
        other.label == label &&
        other.host == host &&
        other.port == port &&
        other.username == username &&
        other.authMode == authMode &&
        other.hostFingerprint == hostFingerprint;
  }

  @override
  int get hashCode =>
      Object.hash(label, host, port, username, authMode, hostFingerprint);
}

class SavedSystemSummary {
  const SavedSystemSummary({required this.id, required this.profile});

  final String id;
  final SystemProfile profile;

  SavedSystemSummary copyWith({String? id, SystemProfile? profile}) {
    return SavedSystemSummary(
      id: id ?? this.id,
      profile: profile ?? this.profile,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SavedSystemSummary &&
        other.id == id &&
        other.profile == profile;
  }

  @override
  int get hashCode => Object.hash(id, profile);
}

class SavedSystem {
  const SavedSystem({
    required this.id,
    required this.profile,
    required this.secrets,
  });

  final String id;
  final SystemProfile profile;
  final ConnectionSecrets secrets;

  SavedSystem copyWith({
    String? id,
    SystemProfile? profile,
    ConnectionSecrets? secrets,
  }) {
    return SavedSystem(
      id: id ?? this.id,
      profile: profile ?? this.profile,
      secrets: secrets ?? this.secrets,
    );
  }

  SavedSystemSummary toSummary() {
    return SavedSystemSummary(id: id, profile: profile);
  }

  @override
  bool operator ==(Object other) {
    return other is SavedSystem &&
        other.id == id &&
        other.profile == profile &&
        other.secrets == secrets;
  }

  @override
  int get hashCode => Object.hash(id, profile, secrets);
}

class SystemCatalogState {
  const SystemCatalogState({
    required this.orderedSystemIds,
    required this.systemsById,
  });

  const SystemCatalogState.empty()
    : orderedSystemIds = const <String>[],
      systemsById = const <String, SavedSystemSummary>{};

  final List<String> orderedSystemIds;
  final Map<String, SavedSystemSummary> systemsById;

  bool get isEmpty => orderedSystemIds.isEmpty;
  bool get isNotEmpty => orderedSystemIds.isNotEmpty;

  SavedSystemSummary? systemForId(String systemId) {
    return systemsById[systemId];
  }

  List<SavedSystemSummary> get orderedSystems {
    return <SavedSystemSummary>[
      for (final systemId in orderedSystemIds)
        if (systemsById[systemId] != null) systemsById[systemId]!,
    ];
  }

  SystemCatalogState copyWith({
    List<String>? orderedSystemIds,
    Map<String, SavedSystemSummary>? systemsById,
  }) {
    return SystemCatalogState(
      orderedSystemIds: orderedSystemIds ?? this.orderedSystemIds,
      systemsById: systemsById ?? this.systemsById,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SystemCatalogState &&
        listEquals(other.orderedSystemIds, orderedSystemIds) &&
        mapEquals(other.systemsById, systemsById);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(orderedSystemIds),
    Object.hashAll(
      systemsById.entries.map<Object>(
        (entry) => Object.hash(entry.key, entry.value),
      ),
    ),
  );
}
