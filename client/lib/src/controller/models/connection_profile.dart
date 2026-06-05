class ConnectionProfile {
  const ConnectionProfile({
    required this.id,
    required this.name,
    required this.relayHost,
    required this.relayPort,
    required this.deviceId,
    required this.sessionId,
    required this.token,
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
  final String token;
  final String username;
  final bool useTls;
  final bool allowBadCertificate;
  final DateTime updatedAt;

  String get effectiveUsername {
    final value = username.trim();
    return value.isEmpty ? deviceId.trim() : value;
  }

  ConnectionProfile copyWith({
    String? id,
    String? name,
    String? relayHost,
    int? relayPort,
    String? deviceId,
    String? sessionId,
    String? token,
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
      token: token ?? this.token,
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
      'token': token,
      'username': username,
      'useTls': useTls,
      'allowBadCertificate': allowBadCertificate,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ConnectionProfile.fromJson(Map<String, Object?> json) {
    final defaults = ConnectionProfile.defaults;
    return ConnectionProfile(
      id: json['id'] as String? ?? defaults.id,
      name: json['name'] as String? ?? defaults.name,
      relayHost: json['relayHost'] as String? ?? defaults.relayHost,
      relayPort: json['relayPort'] as int? ?? defaults.relayPort,
      deviceId: json['deviceId'] as String? ?? defaults.deviceId,
      sessionId: json['sessionId'] as String? ?? defaults.sessionId,
      token: json['token'] as String? ?? defaults.token,
      username: json['username'] as String? ?? defaults.username,
      useTls: json['useTls'] as bool? ?? defaults.useTls,
      allowBadCertificate:
          json['allowBadCertificate'] as bool? ?? defaults.allowBadCertificate,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          defaults.updatedAt,
    );
  }

  static final defaults = ConnectionProfile(
    id: 'default',
    name: '',
    relayHost: '',
    relayPort: 8080,
    deviceId: '',
    sessionId: '',
    token: '',
    username: '',
    useTls: false,
    allowBadCertificate: false,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );
}
