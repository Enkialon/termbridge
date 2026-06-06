import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/agent/ports/agent_settings_repository.dart';
import '../../domain/relay/entities/relay_config.dart';
import '../../domain/relay/ports/relay_config_repository.dart';

const _relayTestTimeout = Duration(seconds: 5);

class RelayTestResult {
  const RelayTestResult({
    required this.testedAt,
    this.latencyMs,
    this.errorMessage,
  });

  final DateTime testedAt;
  final int? latencyMs;
  final String? errorMessage;

  bool get success => latencyMs != null && errorMessage == null;
}

class RelayConfigInput {
  const RelayConfigInput({
    required this.selected,
    required this.name,
    required this.host,
    required this.port,
    required this.relayApiKey,
    required this.useTls,
    required this.allowBadCertificate,
  });

  final RelayConfig? selected;
  final String name;
  final String host;
  final int port;
  final String relayApiKey;
  final bool useTls;
  final bool allowBadCertificate;
}

class RelayService {
  const RelayService({
    required RelayConfigRepository relayConfigs,
    required AgentSettingsRepository agentSettings,
  })  : _relayConfigs = relayConfigs,
        _agentSettings = agentSettings;

  final RelayConfigRepository _relayConfigs;
  final AgentSettingsRepository _agentSettings;

  Future<List<RelayConfig>> loadAll() => _relayConfigs.loadAll();

  Future<RelayConfig> save(RelayConfigInput input) async {
    final selected = input.selected;
    final relayConfig = RelayConfig(
      id: selected?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: input.name,
      relayHost: input.host,
      relayPort: input.port,
      relayApiKey: input.relayApiKey,
      useTls: input.useTls,
      allowBadCertificate: input.useTls && input.allowBadCertificate,
      updatedAt: DateTime.now(),
    );
    final tested = await test(relayConfig);
    await _relayConfigs.save(tested);
    return tested;
  }

  Future<RelayConfig> test(RelayConfig relayConfig) async {
    final test = await testConnection(
      RelayConfigInput(
        selected: relayConfig,
        name: relayConfig.name,
        host: relayConfig.relayHost,
        port: relayConfig.relayPort,
        relayApiKey: relayConfig.relayApiKey,
        useTls: relayConfig.useTls,
        allowBadCertificate: relayConfig.allowBadCertificate,
      ),
    );
    final saved = relayConfig.copyWith(
      lastLatencyMs: test.latencyMs,
      lastTestedAt: test.testedAt,
      lastTestError: test.errorMessage,
      clearLastLatency: test.latencyMs == null,
      clearLastTestError: test.errorMessage == null,
    );
    return saved;
  }

  Future<RelayTestResult> testConnection(RelayConfigInput input) async {
    final testedAt = DateTime.now();
    Socket? openedSocket;
    final stopwatch = Stopwatch()..start();
    try {
      var socket = await Socket.connect(
        input.host,
        input.port,
        timeout: _relayTestTimeout,
      );
      openedSocket = socket;
      if (input.useTls) {
        socket = await SecureSocket.secure(
          socket,
          host: input.host,
          onBadCertificate:
              input.allowBadCertificate ? (_) => true : null,
        ).timeout(_relayTestTimeout);
        openedSocket = socket;
      }

      final lines = socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      final deviceId = '__relay_latency_test_${testedAt.microsecondsSinceEpoch}';
      socket.write(
        '${jsonEncode({
              'type': 'agent.register',
              'deviceId': deviceId,
              'relayApiKey': input.relayApiKey,
            })}\n',
      );
      await socket.flush().timeout(_relayTestTimeout);

      final line = await lines.first.timeout(_relayTestTimeout);
      final decoded = jsonDecode(line) as Map<String, dynamic>;
      final type = decoded['type'] as String?;
      stopwatch.stop();
      if (type == 'ready') {
        return RelayTestResult(
          testedAt: testedAt,
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      }
      if (type == 'error') {
        return RelayTestResult(
          testedAt: testedAt,
          errorMessage: _relayErrorMessage(decoded['message'] as String?),
        );
      }
      return RelayTestResult(
        testedAt: testedAt,
        errorMessage: '响应异常',
      );
    } on TimeoutException {
      return RelayTestResult(testedAt: testedAt, errorMessage: '超时');
    } on HandshakeException {
      return RelayTestResult(testedAt: testedAt, errorMessage: 'TLS 连接失败');
    } on SocketException {
      return RelayTestResult(testedAt: testedAt, errorMessage: '连接失败');
    } on FormatException {
      return RelayTestResult(testedAt: testedAt, errorMessage: '响应异常');
    } catch (error) {
      return RelayTestResult(testedAt: testedAt, errorMessage: error.toString());
    } finally {
      openedSocket?.destroy();
    }
  }

  Future<void> delete(String id) => _relayConfigs.delete(id);

  Future<void> setAsAgentRelay(RelayConfig relayConfig) async {
    final settings = await _agentSettings.load();
    await _agentSettings.save(
      settings.copyWith(relayConfigId: relayConfig.id),
    );
  }
}

String _relayErrorMessage(String? message) {
  return switch (message) {
    'unauthorized' => '认证失败',
    final String value when value.isNotEmpty => value,
    _ => '连接失败',
  };
}
