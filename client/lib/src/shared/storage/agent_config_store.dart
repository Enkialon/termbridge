import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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

  static const defaults = AgentSettings(
    deviceId: '',
    shell: 'cmd.exe',
    serviceGroupId: null,
  );
}

class AgentConfigStore {
  static const _settings = 'agentSettings.v1';
  static const _legacyConfig = 'agentConfig.v1';

  Future<AgentSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_settings);
    if (encoded != null) {
      final json = jsonDecode(encoded) as Map<String, dynamic>;
      final legacyIds = ((json['serviceGroupIds'] as List<dynamic>?) ??
              (json['relayIds'] as List<dynamic>?) ??
              [])
          .whereType<String>()
          .toList();
      return AgentSettings(
        deviceId: json['deviceId'] as String? ?? '',
        shell: json['shell'] as String? ?? AgentSettings.defaults.shell,
        serviceGroupId: json['serviceGroupId'] as String? ??
            (legacyIds.isEmpty ? null : legacyIds.first),
      );
    }

    final legacy = prefs.getString(_legacyConfig);
    if (legacy == null) return AgentSettings.defaults;

    final json = jsonDecode(legacy) as Map<String, dynamic>;
    return AgentSettings.defaults.copyWith(
      deviceId: json['deviceId'] as String? ?? '',
      shell: json['shell'] as String? ?? AgentSettings.defaults.shell,
    );
  }

  Future<void> save(AgentSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _settings,
      jsonEncode({
        'deviceId': settings.deviceId,
        'shell': settings.shell,
        'serviceGroupId': settings.serviceGroupId,
      }),
    );
  }
}
