import '../../domain/agent/entities/agent_config.dart';
import '../../domain/agent/entities/agent_settings.dart';
import '../../domain/agent/entities/agent_status.dart';
import '../../domain/agent/ports/agent_runtime_port.dart';
import '../../domain/agent/ports/agent_settings_repository.dart';
import '../../domain/relay/entities/relay_config.dart';
import '../../domain/relay/ports/relay_config_repository.dart';

class AgentRuntimeState {
  const AgentRuntimeState({
    required this.settings,
    required this.relayConfigs,
  });

  final AgentSettings settings;
  final List<RelayConfig> relayConfigs;
}

class AgentService {
  const AgentService({
    required AgentRuntimePort runtime,
    required AgentSettingsRepository settings,
    required RelayConfigRepository relayConfigs,
  })  : _runtime = runtime,
        _settings = settings,
        _relayConfigs = relayConfigs;

  final AgentRuntimePort _runtime;
  final AgentSettingsRepository _settings;
  final RelayConfigRepository _relayConfigs;

  Stream<AgentStatus> watchStatus() => _runtime.watchStatus();

  Future<AgentRuntimeState> load() async {
    final settings = await _settings.load();
    final relayConfigs = await _relayConfigs.loadAll();
    return AgentRuntimeState(
      settings: settings,
      relayConfigs: relayConfigs,
    );
  }

  Future<AgentSettings> saveSettings(AgentSettings settings) async {
    await _settings.save(settings);
    return settings;
  }

  AgentConfig? _resolveConfig({
    required AgentSettings settings,
    required List<RelayConfig> relayConfigs,
  }) {
    final relayConfigId = settings.relayConfigId;
    if (relayConfigId == null) return null;

    for (final relayConfig in relayConfigs) {
      if (relayConfig.id == relayConfigId) {
        return AgentConfig(
          relayHost: relayConfig.relayHost,
          relayPort: relayConfig.relayPort,
          deviceId: settings.deviceId,
          relayApiKey: relayConfig.relayApiKey,
          password: settings.password,
          shell: settings.shell,
          useTls: relayConfig.useTls,
          allowBadCertificate: relayConfig.allowBadCertificate,
        );
      }
    }
    return null;
  }

  Future<void> start(AgentSettings settings) async {
    final config = _resolveConfig(
      settings: settings,
      relayConfigs: await _relayConfigs.loadAll(),
    );
    if (config == null) {
      throw ArgumentError('请选择一个中继服务器');
    }
    if (config.password.trim().isEmpty) {
      throw ArgumentError('SSH 密码不能为空');
    }
    await _runtime.start(config);
  }

  Future<void> stop() => _runtime.stop();
}
