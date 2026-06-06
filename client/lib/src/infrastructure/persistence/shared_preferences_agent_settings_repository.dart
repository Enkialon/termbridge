import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/agent/entities/agent_settings.dart';
import '../../domain/agent/ports/agent_settings_repository.dart';

class SharedPreferencesAgentSettingsRepository
    implements AgentSettingsRepository {
  static const _settings = 'agentSettings.v1';

  @override
  Future<AgentSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_settings);
    if (encoded != null) {
      final json = jsonDecode(encoded) as Map<String, dynamic>;
      return AgentSettings(
        deviceId: json['deviceId'] as String,
        shell: json['shell'] as String,
        password: json['password'] as String,
        serviceGroupId: json['serviceGroupId'] as String?,
      );
    }

    return const AgentSettings(
      deviceId: '',
      shell: '',
      password: '',
      serviceGroupId: null,
    );
  }

  @override
  Future<void> save(AgentSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _settings,
      jsonEncode({
        'deviceId': settings.deviceId,
        'shell': settings.shell,
        'password': settings.password,
        'serviceGroupId': settings.serviceGroupId,
      }),
    );
  }
}
