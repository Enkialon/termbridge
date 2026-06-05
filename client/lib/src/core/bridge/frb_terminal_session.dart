import 'dart:async';

import '../../agent/models/agent_config.dart';
import '../../agent/models/agent_status.dart';
import '../../controller/models/connection_profile.dart';
import 'core_bridge.dart';

abstract interface class FrbCoreApi {
  Future<void> startAgent(AgentConfig config);

  Future<void> stopAgent();

  Future<AgentStatus> agentStatus();

  Future<int> openTerminal(ConnectionProfile profile);

  Future<void> terminalWrite({
    required int id,
    required List<int> data,
  });

  Future<void> terminalResize({
    required int id,
    required int cols,
    required int rows,
    required int pixelWidth,
    required int pixelHeight,
  });

  Future<List<int>?> terminalNextOutput({
    required int id,
  });

  Future<void> terminalClose({
    required int id,
  });
}

class FrbTerminalSessionHandle implements TerminalSessionHandle {
  FrbTerminalSessionHandle({
    required FrbCoreApi api,
    required int id,
  })  : _api = api,
        _id = id {
    _pumpOutput();
  }

  final FrbCoreApi _api;
  final int _id;
  final _output = StreamController<List<int>>.broadcast();
  bool _closed = false;

  @override
  Stream<List<int>> get output => _output.stream;

  @override
  Future<void> write(List<int> data) {
    if (_closed) return Future<void>.value();
    return _api.terminalWrite(id: _id, data: data);
  }

  @override
  Future<void> resize(int cols, int rows, int pixelWidth, int pixelHeight) {
    if (_closed) return Future<void>.value();
    return _api.terminalResize(
      id: _id,
      cols: cols,
      rows: rows,
      pixelWidth: pixelWidth,
      pixelHeight: pixelHeight,
    );
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _api.terminalClose(id: _id);
    await _output.close();
  }

  Future<void> _pumpOutput() async {
    try {
      while (!_closed) {
        final chunk = await _api.terminalNextOutput(id: _id);
        if (chunk == null) break;
        if (!_closed) {
          _output.add(chunk);
        }
      }
    } catch (error, stackTrace) {
      if (!_closed) {
        _output.addError(error, stackTrace);
      }
    } finally {
      if (!_closed) {
        _closed = true;
        await _output.close();
      }
    }
  }
}
