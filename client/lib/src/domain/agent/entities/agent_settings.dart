class AgentSettings {
  const AgentSettings({
    required this.deviceId,
    required this.shell,
    required this.serviceGroupId,
  });

  final String deviceId;
  final String shell;
  final String? serviceGroupId;

  AgentSettings copyWith({
    String? deviceId,
    String? shell,
    String? serviceGroupId,
  }) {
    return AgentSettings(
      deviceId: deviceId ?? this.deviceId,
      shell: shell ?? this.shell,
      serviceGroupId: serviceGroupId ?? this.serviceGroupId,
    );
  }
}
