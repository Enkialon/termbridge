class AgentSettings {
  const AgentSettings({
    required this.deviceId,
    required this.shell,
    required this.password,
    required this.relayConfigId,
  });

  final String deviceId;
  final String shell;
  final String password;
  final String? relayConfigId;

  AgentSettings copyWith({
    String? deviceId,
    String? shell,
    String? password,
    String? relayConfigId,
  }) {
    return AgentSettings(
      deviceId: deviceId ?? this.deviceId,
      shell: shell ?? this.shell,
      password: password ?? this.password,
      relayConfigId: relayConfigId ?? this.relayConfigId,
    );
  }
}
