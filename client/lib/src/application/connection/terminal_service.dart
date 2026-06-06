import '../../domain/connection/entities/connection_profile.dart';
import '../../domain/connection/ports/terminal_port.dart';
import '../../domain/relay/entities/relay_config.dart';
import '../../domain/relay/ports/relay_config_repository.dart';

class TerminalService {
  const TerminalService({
    required TerminalPort terminalPort,
    required RelayConfigRepository relayConfigs,
  })  : _terminalPort = terminalPort,
        _relayConfigs = relayConfigs;

  final TerminalPort _terminalPort;
  final RelayConfigRepository _relayConfigs;

  Future<TerminalSessionHandle> open(ConnectionProfile profile) async {
    final relayConfig = await _resolveRelayConfig(profile.relayConfigId);
    return _terminalPort.openTerminal(
      ResolvedConnectionProfile(
        profile: profile,
        relayHost: relayConfig.relayHost,
        relayPort: relayConfig.relayPort,
        relayApiKey: relayConfig.relayApiKey,
        useTls: relayConfig.useTls,
        allowBadCertificate: relayConfig.allowBadCertificate,
      ),
    );
  }

  Future<String> describeRelay(String relayConfigId) async {
    final relayConfig = await _resolveRelayConfig(relayConfigId);
    return '${relayConfig.relayHost}:${relayConfig.relayPort}';
  }

  Future<RelayConfig> _resolveRelayConfig(String relayConfigId) async {
    final relayConfigs = await _relayConfigs.loadAll();
    for (final relayConfig in relayConfigs) {
      if (relayConfig.id == relayConfigId) return relayConfig;
    }
    throw StateError('中继服务器配置不存在');
  }
}
