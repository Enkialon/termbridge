import '../entities/agent_config.dart';
import '../entities/agent_status.dart';

abstract interface class AgentRuntimePort {
  Stream<AgentStatus> watchStatus();

  Future<void> start(AgentConfig config);

  Future<void> stop();
}
