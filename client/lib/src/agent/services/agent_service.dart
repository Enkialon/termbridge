import '../../core/bridge/core_bridge.dart';
import '../models/agent_config.dart';
import '../models/agent_status.dart';

class AgentService {
  AgentService({
    CoreBridge bridge = const RustCoreBridge(),
  }) : _bridge = bridge;

  final CoreBridge _bridge;

  Stream<AgentStatus> watchStatus() => _bridge.watchAgentStatus();

  Future<void> start(AgentConfig config) => _bridge.startAgent(config);

  Future<void> stop() => _bridge.stopAgent();
}
