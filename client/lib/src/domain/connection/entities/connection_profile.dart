class ConnectionProfile {
  const ConnectionProfile({
    required this.id,
    required this.name,
    required this.relayConfigId,
    required this.deviceId,
    required this.sessionId,
    required this.password,
    required this.username,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String relayConfigId;
  final String deviceId;
  final String sessionId;
  final String password;
  final String username;
  final DateTime updatedAt;

  String get effectiveUsername {
    final value = username.trim();
    return value.isEmpty ? deviceId.trim() : value;
  }

  ConnectionProfile ensureSessionId() {
    if (sessionId.trim().isNotEmpty) return this;
    return copyWith(
      sessionId: 'session-${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  ConnectionProfile copyWith({
    String? id,
    String? name,
    String? relayConfigId,
    String? deviceId,
    String? sessionId,
    String? password,
    String? username,
    DateTime? updatedAt,
  }) {
    return ConnectionProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      relayConfigId: relayConfigId ?? this.relayConfigId,
      deviceId: deviceId ?? this.deviceId,
      sessionId: sessionId ?? this.sessionId,
      password: password ?? this.password,
      username: username ?? this.username,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'relayConfigId': relayConfigId,
      'deviceId': deviceId,
      'sessionId': sessionId,
      'password': password,
      'username': username,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ConnectionProfile.fromJson(Map<String, Object?> json) {
    return ConnectionProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      relayConfigId: json['relayConfigId'] as String,
      deviceId: json['deviceId'] as String,
      sessionId: json['sessionId'] as String,
      password: json['password'] as String,
      username: json['username'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class ResolvedConnectionProfile {
  const ResolvedConnectionProfile({
    required this.profile,
    required this.relayHost,
    required this.relayPort,
    required this.relayApiKey,
    required this.useTls,
    required this.allowBadCertificate,
  });

  final ConnectionProfile profile;
  final String relayHost;
  final int relayPort;
  final String relayApiKey;
  final bool useTls;
  final bool allowBadCertificate;

  String get deviceId => profile.deviceId;

  String get sessionId => profile.sessionId;

  String get password => profile.password;

  String get effectiveUsername => profile.effectiveUsername;
}
