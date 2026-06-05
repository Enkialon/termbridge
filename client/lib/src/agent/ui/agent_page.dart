import 'package:flutter/material.dart';

import '../models/agent_config.dart';
import '../models/agent_status.dart';
import '../services/agent_service.dart';
import '../../shared/storage/agent_config_store.dart';
import '../../shared/storage/service_group_store.dart';

class AgentPage extends StatefulWidget {
  const AgentPage({
    this.service,
    super.key,
  });

  final AgentService? service;

  @override
  State<AgentPage> createState() => _AgentPageState();
}

class _AgentPageState extends State<AgentPage> {
  late final AgentService _service = widget.service ?? AgentService();
  final _store = AgentConfigStore();
  final _groupStore = ServiceGroupStore();
  var _busy = false;

  Future<void> _start() async {
    final settings = await _store.load();
    final groups = await _groupStore.loadAll();
    AgentConfig? config;
    final groupId = settings.serviceGroupId;
    for (final group in groups) {
      if (group.id == groupId && group.nodes.isNotEmpty) {
        final node = group.nodes.first;
        config = AgentConfig(
          relayHost: node.relayHost,
          relayPort: node.relayPort,
          deviceId: settings.deviceId,
          token: node.token,
          shell: settings.shell,
          useTls: node.useTls,
          allowBadCertificate: node.allowBadCertificate,
        );
        break;
      }
    }
    if (config == null) {
      _showError('请选择一个有节点的中继服务器');
      return;
    }
    setState(() {
      _busy = true;
    });
    try {
      await _service.start(config);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _stop() async {
    setState(() {
      _busy = true;
    });
    try {
      await _service.stop();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('本机')),
      body: SafeArea(
        child: StreamBuilder<AgentStatus>(
          stream: _service.watchStatus(),
          initialData: AgentStatus.stopped(),
          builder: (context, snapshot) {
            final status = snapshot.data ?? AgentStatus.stopped();
            final online = status.kind == AgentStatusKind.online ||
                status.kind == AgentStatusKind.connecting;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      online ? Icons.link : Icons.link_off,
                      color: online
                          ? const Color(0xff70c082)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    title: Text(status.kind.name),
                    subtitle: Text(status.message ?? '本机未配置'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy || online ? null : _start,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('启动'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy || !online ? null : _stop,
                    icon: const Icon(Icons.stop),
                    label: const Text('停止'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
