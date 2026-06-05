import '../storage/agent_config_store.dart';
import '../storage/service_group_store.dart';

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

class RelayConfigService {
  RelayConfigService({
    ServiceGroupStore? groupStore,
    AgentConfigStore? agentStore,
  })  : _groupStore = groupStore ?? ServiceGroupStore(),
        _agentStore = agentStore ?? AgentConfigStore();

  final ServiceGroupStore _groupStore;
  final AgentConfigStore _agentStore;

  Future<List<ServiceGroup>> loadAll() => _groupStore.loadAll();

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
    await _groupStore.save(group);
    return group;
  }

  Future<void> setAsAgentRelay(ServiceGroup group) async {
    final settings = await _agentStore.load();
    await _agentStore.save(settings.copyWith(serviceGroupId: group.id));
  }
}
