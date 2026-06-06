import '../../domain/agent/ports/agent_settings_repository.dart';
import '../../domain/relay/entities/service_group.dart';
import '../../domain/relay/ports/service_group_repository.dart';

class RelayConfigInput {
  const RelayConfigInput({
    required this.selected,
    required this.name,
    required this.host,
    required this.port,
    required this.token,
    required this.useTls,
    required this.allowBadCertificate,
  });

  final ServiceGroup? selected;
  final String name;
  final String host;
  final int port;
  final String token;
  final bool useTls;
  final bool allowBadCertificate;
}

class RelayService {
  const RelayService({
    required ServiceGroupRepository groups,
    required AgentSettingsRepository agentSettings,
  })  : _groups = groups,
        _agentSettings = agentSettings;

  final ServiceGroupRepository _groups;
  final AgentSettingsRepository _agentSettings;

  Future<List<ServiceGroup>> loadAll() => _groups.loadAll();

  Future<ServiceGroup> save(RelayConfigInput input) async {
    final selected = input.selected;
    final group = ServiceGroup(
      id: selected?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: input.name,
      relayHost: input.host,
      relayPort: input.port,
      token: input.token,
      useTls: input.useTls,
      allowBadCertificate: input.useTls && input.allowBadCertificate,
      updatedAt: DateTime.now(),
    );
    await _groups.save(group);
    return group;
  }

  Future<void> setAsAgentRelay(ServiceGroup group) async {
    final settings = await _agentSettings.load();
    await _agentSettings.save(settings.copyWith(serviceGroupId: group.id));
  }
}
