import '../../domain/agent/entities/agent_config.dart';
import '../../domain/agent/entities/agent_settings.dart';
import '../../domain/agent/entities/agent_status.dart';
import '../../domain/agent/ports/agent_runtime_port.dart';
import '../../domain/agent/ports/agent_settings_repository.dart';
import '../../domain/relay/entities/service_group.dart';
import '../../domain/relay/ports/service_group_repository.dart';

class AgentRuntimeState {
  const AgentRuntimeState({
    required this.settings,
    required this.groups,
  });

  final AgentSettings settings;
  final List<ServiceGroup> groups;
}

class AgentService {
  const AgentService({
    required AgentRuntimePort runtime,
    required AgentSettingsRepository settings,
    required ServiceGroupRepository groups,
  })  : _runtime = runtime,
        _settings = settings,
        _groups = groups;

  final AgentRuntimePort _runtime;
  final AgentSettingsRepository _settings;
  final ServiceGroupRepository _groups;

  Stream<AgentStatus> watchStatus() => _runtime.watchStatus();

  Future<AgentRuntimeState> load() async {
    final settings = await _settings.load();
    final groups = await _groups.loadAll();
    return AgentRuntimeState(settings: settings, groups: groups);
  }

  Future<AgentSettings> saveSettings(AgentSettings settings) async {
    await _settings.save(settings);
    return settings;
  }

  AgentConfig? resolveConfig({
    required AgentSettings settings,
    required List<ServiceGroup> groups,
  }) {
    final groupId = settings.serviceGroupId;
    if (groupId == null) return null;

    for (final group in groups) {
      if (group.id == groupId) {
        return AgentConfig(
          relayHost: group.relayHost,
          relayPort: group.relayPort,
          deviceId: settings.deviceId,
          token: group.token,
          shell: settings.shell,
          useTls: group.useTls,
          allowBadCertificate: group.allowBadCertificate,
        );
      }
    }
    return null;
  }

  Future<void> start(AgentConfig config) => _runtime.start(config);

  Future<void> stop() => _runtime.stop();
}
