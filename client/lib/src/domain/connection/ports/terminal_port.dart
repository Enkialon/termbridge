import '../entities/connection_profile.dart';

abstract interface class TerminalPort {
  Future<TerminalSessionHandle> openTerminal(ResolvedConnectionProfile profile);
}

abstract interface class TerminalSessionHandle {
  Stream<List<int>> get output;

  Future<void> write(List<int> data);

  Future<void> resize(int cols, int rows, int pixelWidth, int pixelHeight);

  Future<void> close();
}
