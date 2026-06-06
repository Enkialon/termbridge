class ConnectionProfile {
  const ConnectionProfile({
    required this.id,
    required this.name,
    required this.relayHost,
    required this.relayPort,
    required this.deviceId,
    required this.sessionId,
    required this.relayApiKey,
    required this.password,
    required this.username,
    required this.useTls,
    required this.allowBadCertificate,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String relayHost;
  final int relayPort;
  final String deviceId;
  final String sessionId;
  final String relayApiKey;
  final String password;
  final String username;
  final bool useTls;
  final bool allowBadCertificate;
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
    String? relayHost,
    int? relayPort,
    String? deviceId,
    String? sessionId,
    String? relayApiKey,
    String? password,
    String? username,
    bool? useTls,
    bool? allowBadCertificate,
    DateTime? updatedAt,
  }) {
    return ConnectionProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      relayHost: relayHost ?? this.relayHost,
      relayPort: relayPort ?? this.relayPort,
      deviceId: deviceId ?? this.deviceId,
      sessionId: sessionId ?? this.sessionId,
      relayApiKey: relayApiKey ?? this.relayApiKey,
      password: password ?? this.password,
      username: username ?? this.username,
      useTls: useTls ?? this.useTls,
      allowBadCertificate: allowBadCertificate ?? this.allowBadCertificate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'relayHost': relayHost,
      'relayPort': relayPort,
      'deviceId': deviceId,
      'sessionId': sessionId,
      'relayApiKey': relayApiKey,
      'password': password,
      'username': username,
      'useTls': useTls,
      'allowBadCertificate': allowBadCertificate,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ConnectionProfile.fromJson(Map<String, Object?> json) {
    return ConnectionProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      relayHost: json['relayHost'] as String,
      relayPort: json['relayPort'] as int,
      deviceId: json['deviceId'] as String,
      sessionId: json['sessionId'] as String,
      relayApiKey: json['relayApiKey'] as String,
      password: json['password'] as String,
      username: json['username'] as String,
      useTls: json['useTls'] as bool,
      allowBadCertificate: json['allowBadCertificate'] as bool,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
