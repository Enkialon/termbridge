import '../../domain/connection/entities/connection_profile.dart';
import '../../domain/connection/ports/terminal_port.dart';

class TerminalService {
  const TerminalService({
    required TerminalPort terminalPort,
  }) : _terminalPort = terminalPort;

  final TerminalPort _terminalPort;

  Future<TerminalSessionHandle> open(ConnectionProfile profile) {
    return _terminalPort.openTerminal(profile);
  }
}
