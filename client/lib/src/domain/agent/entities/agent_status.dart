enum AgentStatusKind {
  unsupported,
  stopped,
  connecting,
  online,
  error,
}

class AgentStatus {
  const AgentStatus({
    required this.kind,
    this.message,
  });

  final AgentStatusKind kind;
  final String? message;

  factory AgentStatus.unsupported() {
    return const AgentStatus(
      kind: AgentStatusKind.unsupported,
      message: 'Agent core is not available on this platform.',
    );
  }

  factory AgentStatus.stopped() {
    return const AgentStatus(kind: AgentStatusKind.stopped);
  }
}
