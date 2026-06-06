class AgentSettings {
  const AgentSettings({
    required this.deviceId,
    required this.shell,
    required this.password,
    required this.serviceGroupId,
  });

  final String deviceId;
  final String shell;
  final String password;
  final String? serviceGroupId;

  AgentSettings copyWith({
    String? deviceId,
    String? shell,
    String? password,
    String? serviceGroupId,
  }) {
    return AgentSettings(
      deviceId: deviceId ?? this.deviceId,
      shell: shell ?? this.shell,
      password: password ?? this.password,
      serviceGroupId: serviceGroupId ?? this.serviceGroupId,
    );
  }
}
