class RelayConfig {
  const RelayConfig({
    required this.id,
    required this.name,
    required this.relayHost,
    required this.relayPort,
    required this.relayApiKey,
    required this.useTls,
    required this.allowBadCertificate,
    required this.updatedAt,
    this.lastLatencyMs,
    this.lastTestedAt,
    this.lastTestError,
  });

  final String id;
  final String name;
  final String relayHost;
  final int relayPort;
  final String relayApiKey;
  final bool useTls;
  final bool allowBadCertificate;
  final DateTime updatedAt;
  final int? lastLatencyMs;
  final DateTime? lastTestedAt;
  final String? lastTestError;

  RelayConfig copyWith({
    String? id,
    String? name,
    String? relayHost,
    int? relayPort,
    String? relayApiKey,
    bool? useTls,
    bool? allowBadCertificate,
    DateTime? updatedAt,
    int? lastLatencyMs,
    DateTime? lastTestedAt,
    String? lastTestError,
    bool clearLastLatency = false,
    bool clearLastTestError = false,
  }) {
    return RelayConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      relayHost: relayHost ?? this.relayHost,
      relayPort: relayPort ?? this.relayPort,
      relayApiKey: relayApiKey ?? this.relayApiKey,
      useTls: useTls ?? this.useTls,
      allowBadCertificate: allowBadCertificate ?? this.allowBadCertificate,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLatencyMs:
          clearLastLatency ? null : lastLatencyMs ?? this.lastLatencyMs,
      lastTestedAt: lastTestedAt ?? this.lastTestedAt,
      lastTestError:
          clearLastTestError ? null : lastTestError ?? this.lastTestError,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'relayHost': relayHost,
      'relayPort': relayPort,
      'relayApiKey': relayApiKey,
      'useTls': useTls,
      'allowBadCertificate': allowBadCertificate,
      'updatedAt': updatedAt.toIso8601String(),
      'lastLatencyMs': lastLatencyMs,
      'lastTestedAt': lastTestedAt?.toIso8601String(),
      'lastTestError': lastTestError,
    };
  }

  factory RelayConfig.fromJson(Map<String, Object?> json) {
    return RelayConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      relayHost: json['relayHost'] as String,
      relayPort: json['relayPort'] as int,
      relayApiKey: json['relayApiKey'] as String,
      useTls: json['useTls'] as bool,
      allowBadCertificate: json['allowBadCertificate'] as bool,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastLatencyMs: json['lastLatencyMs'] as int?,
      lastTestedAt: switch (json['lastTestedAt']) {
        final String value => DateTime.parse(value),
        _ => null,
      },
      lastTestError: json['lastTestError'] as String?,
    );
  }
}
