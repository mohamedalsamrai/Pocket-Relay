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

    final identityLabel = connectionIdentityLabelForFields(
      host: host,
      port: port,
      username: username,
      usePlaceholder: false,
    );
    return identityLabel.isEmpty || normalizedLabel != identityLabel;
  }

  String get displayLabel {
    final normalizedLabel = label.trim();
    if (normalizedLabel.isNotEmpty) {
      return normalizedLabel;
    }

    return connectionIdentityLabelForFields(
      host: host,
      port: port,
      username: username,
      usePlaceholder: true,
    );
  }

  String get connectionIdentityLabel {
    return connectionIdentityLabelForFields(
      host: host,
      port: port,
      username: username,
      usePlaceholder: true,
    );
  }

  static String connectionIdentityLabelForProfile(
    ConnectionProfile profile, {
    bool usePlaceholder = true,
  }) {
    return connectionIdentityLabelForFields(
      host: profile.host,
      port: profile.port,
      username: profile.username,
      usePlaceholder: usePlaceholder,
    );
  }

  static String connectionIdentityLabelForFields({
    required String host,
    required int port,
    required String username,
    required bool usePlaceholder,
  }) {
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
    return SystemProfile(
      label: _storedLabelFromJson(json),
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

  static String _storedLabelFromJson(Map<String, dynamic> json) {
    final rawLabel = json['label'];
    if (rawLabel is String) {
      return rawLabel.trim();
    }

    return _firstNonBlankTrimmedString(<Object?>[
          json['name'],
          json['displayLabel'],
          json['identityLabel'],
        ]) ??
        '';
  }

  static String? _firstNonBlankTrimmedString(Iterable<Object?> candidates) {
    for (final candidate in candidates) {
      if (candidate is! String) {
        continue;
      }
      final trimmed = candidate.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }
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
