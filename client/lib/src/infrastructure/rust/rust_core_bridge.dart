import 'dart:async';

import '../../domain/agent/entities/agent_config.dart';
import '../../domain/agent/entities/agent_status.dart';
import '../../domain/agent/ports/agent_runtime_port.dart';
import '../../domain/connection/entities/connection_profile.dart';
import '../../domain/connection/ports/terminal_port.dart';
import 'frb_terminal_session.dart';

class UnsupportedRustCoreBridge implements AgentRuntimePort, TerminalPort {
  const UnsupportedRustCoreBridge();

  @override
  Stream<AgentStatus> watchStatus() {
    return Stream.value(AgentStatus.unsupported());
  }

  @override
  Future<void> start(AgentConfig config) {
    throw UnsupportedError('Rust core bridge is not wired yet.');
  }

  @override
  Future<void> stop() {
    throw UnsupportedError('Rust core bridge is not wired yet.');
  }

  @override
  Future<TerminalSessionHandle> openTerminal(ResolvedConnectionProfile profile) {
    throw UnsupportedError('Rust core bridge is not wired yet.');
  }
}

class RustCoreBridge implements AgentRuntimePort, TerminalPort {
  const RustCoreBridge({
    FrbCoreApi? api,
  }) : _api = api;

  final FrbCoreApi? _api;

  @override
  Stream<AgentStatus> watchStatus() {
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
  Future<void> start(AgentConfig config) {
    final api = _requireApi();
    return api.startAgent(config);
  }

  @override
  Future<void> stop() {
    final api = _requireApi();
    return api.stopAgent();
  }

  @override
  Future<TerminalSessionHandle> openTerminal(
    ResolvedConnectionProfile profile,
  ) async {
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
