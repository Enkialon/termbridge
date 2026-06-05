import '../../agent/models/agent_config.dart';
import '../../agent/models/agent_status.dart';
import '../../controller/models/connection_profile.dart';
import 'frb_terminal_session.dart';

abstract class CoreBridge {
  Stream<AgentStatus> watchAgentStatus();

  Future<void> startAgent(AgentConfig config);

  Future<void> stopAgent();

  Future<TerminalSessionHandle> openTerminal(ConnectionProfile profile);
}

abstract class TerminalSessionHandle {
  Stream<List<int>> get output;

  Future<void> write(List<int> data);

  Future<void> resize(int cols, int rows, int pixelWidth, int pixelHeight);

  Future<void> close();
}

class UnsupportedCoreBridge implements CoreBridge {
  const UnsupportedCoreBridge();

  @override
  Stream<AgentStatus> watchAgentStatus() {
    return Stream.value(AgentStatus.unsupported());
  }

  @override
  Future<void> startAgent(AgentConfig config) {
    throw UnsupportedError('Rust core bridge is not wired yet.');
  }

  @override
  Future<void> stopAgent() {
    throw UnsupportedError('Rust core bridge is not wired yet.');
  }

  @override
  Future<TerminalSessionHandle> openTerminal(ConnectionProfile profile) {
    throw UnsupportedError('Rust core bridge is not wired yet.');
  }
}

class RustCoreBridge implements CoreBridge {
  const RustCoreBridge({
    FrbCoreApi? api,
  }) : _api = api;

  final FrbCoreApi? _api;

  @override
  Stream<AgentStatus> watchAgentStatus() {
    final api = _api;
    if (api == null) {
      return Stream.value(
        const AgentStatus(
          kind: AgentStatusKind.stopped,
          message: 'Rust core bridge is waiting for generated bindings.',
        ),
      );
    }
    return Stream.periodic(const Duration(seconds: 1))
        .asyncMap((_) => api.agentStatus());
  }

  @override
  Future<void> startAgent(AgentConfig config) {
    final api = _requireApi();
    return api.startAgent(config);
  }

  @override
  Future<void> stopAgent() {
    final api = _requireApi();
    return api.stopAgent();
  }

  @override
  Future<TerminalSessionHandle> openTerminal(ConnectionProfile profile) async {
    final api = _requireApi();
    final id = await api.openTerminal(profile);
    return FrbTerminalSessionHandle(
      api: api,
      id: id,
    );
  }

  FrbCoreApi _requireApi() {
    final api = _api;
    if (api == null) {
      throw UnimplementedError(
        'Run flutter_rust_bridge_codegen generate and provide the generated API adapter.',
      );
    }
    return api;
  }
}
