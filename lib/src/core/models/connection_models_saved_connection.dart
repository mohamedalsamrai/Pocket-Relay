part of 'connection_models.dart';

class SavedProfile {
  const SavedProfile({required this.profile, required this.secrets});

  final ConnectionProfile profile;
  final ConnectionSecrets secrets;

  SavedProfile copyWith({
    ConnectionProfile? profile,
    ConnectionSecrets? secrets,
  }) {
    return SavedProfile(
      profile: profile ?? this.profile,
      secrets: secrets ?? this.secrets,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SavedProfile &&
        other.profile == profile &&
        other.secrets == secrets;
  }

  @override
  int get hashCode => Object.hash(profile, secrets);
}

class SavedConnectionSummary {
  const SavedConnectionSummary({required this.id, required this.profile});

  final String id;
  final ConnectionProfile profile;

  SavedConnectionSummary copyWith({String? id, ConnectionProfile? profile}) {
    return SavedConnectionSummary(
      id: id ?? this.id,
      profile: profile ?? this.profile,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SavedConnectionSummary &&
        other.id == id &&
        other.profile == profile;
  }

  @override
  int get hashCode => Object.hash(id, profile);
}

class SavedConnection {
  const SavedConnection({
    required this.id,
    required this.profile,
    required this.secrets,
  });

  final String id;
  final ConnectionProfile profile;
  final ConnectionSecrets secrets;

  SavedConnection copyWith({
    String? id,
    ConnectionProfile? profile,
    ConnectionSecrets? secrets,
  }) {
    return SavedConnection(
      id: id ?? this.id,
      profile: profile ?? this.profile,
      secrets: secrets ?? this.secrets,
    );
  }

  SavedConnectionSummary toSummary() {
    return SavedConnectionSummary(id: id, profile: profile);
  }

  @override
  bool operator ==(Object other) {
    return other is SavedConnection &&
        other.id == id &&
        other.profile == profile &&
        other.secrets == secrets;
  }

  @override
  int get hashCode => Object.hash(id, profile, secrets);
}
