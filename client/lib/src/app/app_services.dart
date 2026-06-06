import '../application/agent/agent_service.dart';
import '../application/connection/connection_service.dart';
import '../application/connection/terminal_service.dart';
import '../application/relay/relay_service.dart';
import '../domain/agent/ports/agent_runtime_port.dart';
import '../domain/connection/ports/terminal_port.dart';
import '../infrastructure/persistence/shared_preferences_agent_settings_repository.dart';
import '../infrastructure/persistence/shared_preferences_connection_profile_repository.dart';
import '../infrastructure/persistence/shared_preferences_relay_config_repository.dart';

class AppServices {
  AppServices({
    required this.connections,
    required this.terminal,
    required this.agent,
    required this.relay,
  });

  factory AppServices.create({
    required AgentRuntimePort runtime,
    required TerminalPort terminalPort,
  }) {
    final profiles = SharedPreferencesConnectionProfileRepository();
    final relayConfigs = SharedPreferencesRelayConfigRepository();
    final agentSettings = SharedPreferencesAgentSettingsRepository();
    return AppServices(
      connections: ConnectionService(profiles: profiles),
      terminal: TerminalService(
        terminalPort: terminalPort,
        relayConfigs: relayConfigs,
      ),
      agent: AgentService(
        runtime: runtime,
        settings: agentSettings,
        relayConfigs: relayConfigs,
      ),
      relay: RelayService(
        relayConfigs: relayConfigs,
        agentSettings: agentSettings,
      ),
    );
  }

  final ConnectionService connections;
  final TerminalService terminal;
  final AgentService agent;
  final RelayService relay;
}
