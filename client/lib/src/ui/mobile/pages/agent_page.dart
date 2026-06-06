import 'package:flutter/material.dart';

import '../../../application/agent/agent_service.dart';
import '../../../domain/agent/entities/agent_settings.dart';
import '../../../domain/agent/entities/agent_status.dart';
import '../../../domain/relay/entities/service_group.dart';

class AgentPage extends StatefulWidget {
  const AgentPage({
    required this.service,
    super.key,
  });

  final AgentService service;

  @override
  State<AgentPage> createState() => _AgentPageState();
}

class _AgentPageState extends State<AgentPage> {
  final _formKey = GlobalKey<FormState>();
  final _deviceId = TextEditingController();
  final _shell = TextEditingController();
  final _password = TextEditingController();
  var _groups = <ServiceGroup>[];
  String? _selectedGroupId;
  var _showPassword = false;
  var _busy = false;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = await widget.service.load();
    if (!mounted) return;
    final selectedGroupId =
        state.groups.any((group) => group.id == state.settings.serviceGroupId)
            ? state.settings.serviceGroupId
            : null;
    setState(() {
      _deviceId.text = state.settings.deviceId;
      _shell.text = state.settings.shell;
      _password.text = state.settings.password;
      _groups = state.groups;
      _selectedGroupId = selectedGroupId;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _deviceId.dispose();
    _shell.dispose();
    _password.dispose();
    super.dispose();
  }

  AgentSettings? _settingsFromForm() {
    if (!_formKey.currentState!.validate()) return null;
    return AgentSettings(
      deviceId: _deviceId.text.trim(),
      shell: _shell.text.trim(),
      password: _password.text,
      serviceGroupId: _selectedGroupId,
    );
  }

  Future<AgentSettings?> _save({bool showMessage = true}) async {
    final settings = _settingsFromForm();
    if (settings == null) return null;
    await widget.service.saveSettings(settings);
    if (mounted && showMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本机配置已保存')),
      );
    }
    return settings;
  }

  Future<void> _start() async {
    final settings = await _save(showMessage: false);
    if (settings == null) return;
    final config = widget.service.resolveConfig(
      settings: settings,
      groups: _groups,
    );
    if (config == null) {
      _showError('请选择一个中继服务器');
      return;
    }
    await _run(() => widget.service.start(config));
  }

  Future<void> _stop() => _run(widget.service.stop);

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
    });
    try {
      await action();
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
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('本机')),
      body: SafeArea(
        child: StreamBuilder<AgentStatus>(
          stream: widget.service.watchStatus(),
          initialData: AgentStatus.stopped(),
          builder: (context, snapshot) {
            final status = snapshot.data ?? AgentStatus.stopped();
            final online = status.kind == AgentStatusKind.online ||
                status.kind == AgentStatusKind.connecting;
            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  _Section(
                    title: '状态',
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
                        subtitle: Text(status.message ?? '未连接'),
                      ),
                    ],
                  ),
                  _Section(
                    title: '本机',
                    children: [
                      _field(_deviceId, '设备 ID', Icons.computer_outlined),
                      _field(_shell, 'Shell', Icons.terminal_outlined),
                      _field(
                        _password,
                        'SSH 密码',
                        Icons.password_outlined,
                        obscureText: !_showPassword,
                        validator: (_) => null,
                        suffixIcon: IconButton(
                          tooltip: _showPassword ? '隐藏 SSH 密码' : '显示 SSH 密码',
                          onPressed: () {
                            setState(
                              () => _showPassword = !_showPassword,
                            );
                          },
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ],
                  ),
                  _Section(
                    title: '中继服务器',
                    children: [
                      if (_groups.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text('请先在“中继服务器”里添加服务器'),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedGroupId,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: '选择中继服务器',
                              prefixIcon: Icon(Icons.hub_outlined, size: 20),
                            ),
                            items: _groups
                                .map(
                                  (group) => DropdownMenuItem(
                                    value: group.id,
                                    child: Text(
                                      group.name.isEmpty
                                          ? '未命名中继服务器'
                                          : group.name,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: online
                                ? null
                                : (value) {
                                    setState(() => _selectedGroupId = value);
                                  },
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: StreamBuilder<AgentStatus>(
          stream: widget.service.watchStatus(),
          initialData: AgentStatus.stopped(),
          builder: (context, snapshot) {
            final status = snapshot.data ?? AgentStatus.stopped();
            final online = status.kind == AgentStatusKind.online ||
                status.kind == AgentStatusKind.connecting;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy || online ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('保存'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy || online || _selectedGroupId == null
                          ? null
                          : _start,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('启动'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.outlined(
                    tooltip: '停止',
                    onPressed: _busy || !online ? null : _stop,
                    icon: const Icon(Icons.stop),
                  ),
                ],
              ),
            );
          },
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
        enabled: !_busy,
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
