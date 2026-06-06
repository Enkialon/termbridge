import '../entities/agent_settings.dart';

abstract interface class AgentSettingsRepository {
  Future<AgentSettings> load();

  Future<void> save(AgentSettings settings);
}
