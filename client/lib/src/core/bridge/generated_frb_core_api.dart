import 'dart:typed_data';

import '../../agent/models/agent_config.dart';
import '../../agent/models/agent_status.dart';
import '../../controller/models/connection_profile.dart';
import '../../rust/frb_api.dart' as frb;
import '../../rust/frb_generated.dart';
import 'frb_terminal_session.dart';

class GeneratedFrbCoreApi implements FrbCoreApi {
  const GeneratedFrbCoreApi();

  static Future<GeneratedFrbCoreApi> create() async {
    await RustLib.init();
    return const GeneratedFrbCoreApi();
  }

  @override
  Future<void> startAgent(AgentConfig config) {
    return frb.startAgent(config: _agentConfig(config));
  }

  @override
  Future<void> stopAgent() {
    return frb.stopAgent();
  }

  @override
  Future<AgentStatus> agentStatus() async {
    final status = await frb.agentStatus();
    return AgentStatus(
      kind: switch (status.kind) {
        'connecting' => AgentStatusKind.connecting,
        'online' => AgentStatusKind.online,
        'error' => AgentStatusKind.error,
        'unsupported' => AgentStatusKind.unsupported,
        _ => AgentStatusKind.stopped,
      },
      message: status.message,
    );
  }

  @override
  Future<int> openTerminal(ConnectionProfile profile) {
    return frb.openTerminal(profile: _terminalProfile(profile));
  }

  @override
  Future<void> terminalWrite({
    required int id,
    required List<int> data,
  }) {
    return frb.terminalWrite(
      id: id,
      data: Uint8List.fromList(data),
    );
  }

  @override
  Future<void> terminalResize({
    required int id,
    required int cols,
    required int rows,
    required int pixelWidth,
    required int pixelHeight,
  }) {
    return frb.terminalResize(
      id: id,
      cols: cols,
      rows: rows,
      pixelWidth: pixelWidth,
      pixelHeight: pixelHeight,
    );
  }

  @override
  Future<List<int>?> terminalNextOutput({
    required int id,
  }) async {
    final output = await frb.terminalNextOutput(id: id);
    return output?.toList();
  }

  @override
  Future<void> terminalClose({
    required int id,
  }) {
    return frb.terminalClose(id: id);
  }

  frb.FrbAgentConfig _agentConfig(AgentConfig config) {
    return frb.FrbAgentConfig(
      relayHost: config.relayHost,
      relayPort: config.relayPort,
      deviceId: config.deviceId,
      token: config.token,
      shell: config.shell,
      useTls: config.useTls,
      allowBadCertificate: config.allowBadCertificate,
    );
  }

  frb.FrbTerminalProfile _terminalProfile(ConnectionProfile profile) {
    return frb.FrbTerminalProfile(
      relayHost: profile.relayHost,
      relayPort: profile.relayPort,
      deviceId: profile.deviceId,
      sessionId: profile.sessionId,
      token: profile.token,
      username: profile.username,
      useTls: profile.useTls,
      allowBadCertificate: profile.allowBadCertificate,
    );
  }
}
