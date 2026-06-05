import '../../shared/storage/agent_config_store.dart';
import '../../shared/storage/service_group_store.dart';
import '../models/agent_config.dart';
import '../models/agent_status.dart';
import 'agent_service.dart';

class AgentRuntimeState {
  const AgentRuntimeState({
    required this.settings,
    required this.groups,
  });

  final AgentSettings settings;
  final List<ServiceGroup> groups;
}

class AgentRuntimeCoordinator {
  AgentRuntimeCoordinator({
    required AgentService service,
    AgentConfigStore? settingsStore,
    ServiceGroupStore? groupStore,
  })  : _service = service,
        _settingsStore = settingsStore ?? AgentConfigStore(),
        _groupStore = groupStore ?? ServiceGroupStore();

  final AgentService _service;
  final AgentConfigStore _settingsStore;
  final ServiceGroupStore _groupStore;

  Stream<AgentStatus> watchStatus() => _service.watchStatus();

  Future<AgentRuntimeState> load() async {
    final settings = await _settingsStore.load();
    final groups = await _groupStore.loadAll();
    return AgentRuntimeState(settings: settings, groups: groups);
  }

  Future<AgentSettings> saveSettings(AgentSettings settings) async {
    await _settingsStore.save(settings);
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

  Future<void> start(AgentConfig config) => _service.start(config);

  Future<void> stop() => _service.stop();
}
