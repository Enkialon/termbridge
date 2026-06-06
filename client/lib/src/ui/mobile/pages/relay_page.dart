import 'package:flutter/material.dart';

import '../../../application/relay/relay_service.dart';
import '../../../domain/relay/entities/relay_config.dart';

class RelayPage extends StatefulWidget {
  const RelayPage({
    required this.service,
    super.key,
  });

  final RelayService service;

  @override
  State<RelayPage> createState() => _RelayPageState();
}

class _RelayPageState extends State<RelayPage> {
  late Future<List<RelayConfig>> _groups = widget.service.loadAll();
  final _testing = <String>{};

  void _reload() {
    setState(() {
      _groups = widget.service.loadAll();
    });
  }

  Future<void> _openEditor([RelayConfig? group]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => RelayEditorPage(
          group: group,
          service: widget.service,
        ),
      ),
    );
    if (saved == true) _reload();
  }

  Future<void> _test(RelayConfig group) async {
    if (_testing.contains(group.id)) return;
    setState(() => _testing.add(group.id));
    try {
      final saved = await widget.service.testAndSave(group);
      if (!mounted) return;
      setState(() {
        _groups = widget.service.loadAll();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_relayTestMessage(saved))),
      );
    } finally {
      if (mounted) {
        setState(() => _testing.remove(group.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('中继服务器')),
      floatingActionButton: FloatingActionButton(
        tooltip: '新建中继服务器',
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: FutureBuilder<List<RelayConfig>>(
          future: _groups,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final groups = snapshot.data!;
            if (groups.isEmpty) {
              return Center(
                child: FilledButton.icon(
                  onPressed: () => _openEditor(),
                  icon: const Icon(Icons.add),
                  label: const Text('新建中继服务器'),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              itemCount: groups.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final group = groups[index];
                return Material(
                  color: const Color(0xff11181c),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _openEditor(group),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                      child: Row(
                        children: [
                          const Icon(Icons.hub_outlined),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.name.isEmpty
                                      ? '未命名中继服务器'
                                      : group.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  group.relayHost.isEmpty
                                      ? '未配置地址'
                                      : '${group.relayHost}:${group.relayPort}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _RelayTestButton(
                            group: group,
                            testing: _testing.contains(group.id),
                            onPressed: () => _test(group),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class RelayEditorPage extends StatefulWidget {
  const RelayEditorPage({
    required this.service,
    this.group,
    super.key,
  });

  final RelayService service;
  final RelayConfig? group;

  @override
  State<RelayEditorPage> createState() => _RelayEditorPageState();
}

class _RelayEditorPageState extends State<RelayEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController();
  final _relayApiKey = TextEditingController();
  var _useTls = false;
  var _allowBadCertificate = false;
  var _showRelayApiKey = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final group = widget.group;
    _name.text = group?.name ?? '';
    _host.text = group?.relayHost ?? '';
    _port.text = group == null ? '' : group.relayPort.toString();
    _relayApiKey.text = group?.relayApiKey ?? '';
    _useTls = group?.useTls ?? false;
    _allowBadCertificate = group?.allowBadCertificate ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _relayApiKey.dispose();
    super.dispose();
  }

  Future<RelayConfig?> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return null;
    setState(() => _saving = true);
    try {
      return await widget.service.save(
        RelayConfigInput(
          selected: widget.group,
          name: _name.text.trim(),
          host: _host.text.trim(),
          port: int.parse(_port.text.trim()),
          relayApiKey: _relayApiKey.text,
          useTls: _useTls,
          allowBadCertificate: _allowBadCertificate,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAndClose() async {
    final saved = await _save();
    if (!mounted || saved == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_relayTestMessage(saved))),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group == null ? '新建中继服务器' : '中继服务器详情'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _Section(
                title: '配置',
                children: [
                  _field(_name, '中继服务器名称', Icons.label_outline),
                  _field(_host, '服务器地址', Icons.dns_outlined),
                  _field(
                    _port,
                    '端口',
                    Icons.numbers,
                    keyboardType: TextInputType.number,
                    validator: _validatePort,
                  ),
                  _field(
                    _relayApiKey,
                    'Relay API Key',
                    Icons.key_outlined,
                    obscureText: !_showRelayApiKey,
                    suffixIcon: IconButton(
                      tooltip: _showRelayApiKey ? '隐藏 API Key' : '显示 API Key',
                      onPressed: () {
                        setState(() => _showRelayApiKey = !_showRelayApiKey);
                      },
                      icon: Icon(
                        _showRelayApiKey
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('TLS'),
                    secondary: const Icon(Icons.lock_outline),
                    value: _useTls,
                    onChanged: (value) {
                      setState(() {
                        _useTls = value;
                        if (!value) _allowBadCertificate = false;
                      });
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('允许不安全证书'),
                    secondary: const Icon(Icons.warning_amber_outlined),
                    value: _allowBadCertificate,
                    onChanged: _useTls
                        ? (value) {
                            setState(() => _allowBadCertificate = value);
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: _saving ? null : _saveAndClose,
            icon: const Icon(Icons.save_outlined),
            label: const Text('保存'),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator ?? _validateRequired,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '必填';
    }
    return null;
  }

  String? _validatePort(String? value) {
    final port = int.tryParse(value ?? '');
    if (port == null || port <= 0 || port > 65535) {
      return '请输入 1-65535';
    }
    return null;
  }
}

String _relayTestLabel(RelayConfig group) {
  if (group.lastLatencyMs != null) return '${group.lastLatencyMs}ms';
  if (group.lastTestError != null) return group.lastTestError!;
  return '测试';
}

String _relayTestMessage(RelayConfig group) {
  if (group.lastLatencyMs != null) {
    return '中继服务器已保存，延迟 ${group.lastLatencyMs}ms';
  }
  return '中继服务器已保存，测试${group.lastTestError ?? '未完成'}';
}

IconData _relayTestIcon(RelayConfig group) {
  if (group.lastLatencyMs != null) return Icons.speed_outlined;
  if (group.lastTestError != null) return Icons.error_outline;
  return Icons.network_check_outlined;
}

class _RelayTestButton extends StatelessWidget {
  const _RelayTestButton({
    required this.group,
    required this.testing,
    required this.onPressed,
  });

  final RelayConfig group;
  final bool testing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: testing ? null : onPressed,
      icon: testing
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(_relayTestIcon(group), size: 18),
      label: Text(_relayTestLabel(group)),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
