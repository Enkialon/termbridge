class ServiceGroup {
  const ServiceGroup({
    required this.id,
    required this.name,
    required this.relayHost,
    required this.relayPort,
    required this.relayApiKey,
    required this.useTls,
    required this.allowBadCertificate,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String relayHost;
  final int relayPort;
  final String relayApiKey;
  final bool useTls;
  final bool allowBadCertificate;
  final DateTime updatedAt;

  ServiceGroup copyWith({
    String? id,
    String? name,
    String? relayHost,
    int? relayPort,
    String? relayApiKey,
    bool? useTls,
    bool? allowBadCertificate,
    DateTime? updatedAt,
  }) {
    return ServiceGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      relayHost: relayHost ?? this.relayHost,
      relayPort: relayPort ?? this.relayPort,
      relayApiKey: relayApiKey ?? this.relayApiKey,
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
      'relayApiKey': relayApiKey,
      'useTls': useTls,
      'allowBadCertificate': allowBadCertificate,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ServiceGroup.fromJson(Map<String, Object?> json) {
    return ServiceGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      relayHost: json['relayHost'] as String,
      relayPort: json['relayPort'] as int,
      relayApiKey: json['relayApiKey'] as String,
      useTls: json['useTls'] as bool,
      allowBadCertificate: json['allowBadCertificate'] as bool,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
