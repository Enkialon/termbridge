class AgentConfig {
  const AgentConfig({
    required this.relayHost,
    required this.relayPort,
    required this.deviceId,
    required this.token,
    required this.shell,
    required this.useTls,
    required this.allowBadCertificate,
  });

  final String relayHost;
  final int relayPort;
  final String deviceId;
  final String token;
  final String shell;
  final bool useTls;
  final bool allowBadCertificate;

  AgentConfig copyWith({
    String? relayHost,
    int? relayPort,
    String? deviceId,
    String? token,
    String? shell,
    bool? useTls,
    bool? allowBadCertificate,
  }) {
    return AgentConfig(
      relayHost: relayHost ?? this.relayHost,
      relayPort: relayPort ?? this.relayPort,
      deviceId: deviceId ?? this.deviceId,
      token: token ?? this.token,
      shell: shell ?? this.shell,
      useTls: useTls ?? this.useTls,
      allowBadCertificate: allowBadCertificate ?? this.allowBadCertificate,
    );
  }

  static const defaults = AgentConfig(
    relayHost: '',
    relayPort: 8080,
    deviceId: '',
    token: '',
    shell: 'cmd.exe',
    useTls: false,
    allowBadCertificate: false,
  );
}
