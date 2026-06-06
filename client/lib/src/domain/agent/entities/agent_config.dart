class AgentConfig {
  const AgentConfig({
    required this.relayHost,
    required this.relayPort,
    required this.deviceId,
    required this.relayApiKey,
    required this.password,
    required this.shell,
    required this.useTls,
    required this.allowBadCertificate,
  });

  final String relayHost;
  final int relayPort;
  final String deviceId;
  final String relayApiKey;
  final String password;
  final String shell;
  final bool useTls;
  final bool allowBadCertificate;

  AgentConfig copyWith({
    String? relayHost,
    int? relayPort,
    String? deviceId,
    String? relayApiKey,
    String? password,
    String? shell,
    bool? useTls,
    bool? allowBadCertificate,
  }) {
    return AgentConfig(
      relayHost: relayHost ?? this.relayHost,
      relayPort: relayPort ?? this.relayPort,
      deviceId: deviceId ?? this.deviceId,
      relayApiKey: relayApiKey ?? this.relayApiKey,
      password: password ?? this.password,
      shell: shell ?? this.shell,
      useTls: useTls ?? this.useTls,
      allowBadCertificate: allowBadCertificate ?? this.allowBadCertificate,
    );
  }
}
