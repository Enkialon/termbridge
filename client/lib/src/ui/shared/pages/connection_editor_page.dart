import 'package:flutter/material.dart';

import '../../../application/connection/connection_service.dart';
import '../../../application/connection/terminal_service.dart';
import '../../../application/relay/relay_service.dart';
import '../../../domain/connection/entities/connection_profile.dart';
import '../../../domain/relay/entities/relay_config.dart';
import 'terminal_page.dart';

class ConnectionEditorPage extends StatefulWidget {
  const ConnectionEditorPage({
    required this.profile,
    required this.isNew,
    required this.connectionService,
    required this.relayService,
    required this.terminalService,
    this.showConnectAction = true,
    super.key,
  });

  final ConnectionProfile profile;
  final bool isNew;
  final ConnectionService connectionService;
  final RelayService relayService;
  final TerminalService terminalService;
  final bool showConnectAction;

  @override
  State<ConnectionEditorPage> createState() => _ConnectionEditorPageState();
}

class _ConnectionEditorPageState extends State<ConnectionEditorPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _deviceId;
  late final TextEditingController _sessionId;
  late final TextEditingController _password;
  late final TextEditingController _username;

  var _relayConfigs = <RelayConfig>[];
  String? _selectedRelayConfigId;
  bool _showPassword = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _name = TextEditingController(text: profile.name);
    _deviceId = TextEditingController(text: profile.deviceId);
    _sessionId = TextEditingController(text: profile.sessionId);
    _password = TextEditingController(text: profile.password);
    _username = TextEditingController(text: profile.username);
    _loadRelayConfigs();
  }

  Future<void> _loadRelayConfigs() async {
    final relayConfigs = await widget.relayService.loadAll();
    if (!mounted) return;
    final selectedRelayConfigId =
        relayConfigs.any((value) => value.id == widget.profile.relayConfigId)
            ? widget.profile.relayConfigId
            : null;
    setState(() {
      _relayConfigs = relayConfigs;
      _selectedRelayConfigId = selectedRelayConfigId;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _deviceId.dispose();
    _sessionId.dispose();
    _password.dispose();
    _username.dispose();
    super.dispose();
  }

  ConnectionProfile? _profileFromForm() {
    if (!_formKey.currentState!.validate()) return null;
    final relayConfig = _selectedRelayConfig;
    if (relayConfig == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择一个中继服务器')),
      );
      return null;
    }
    return widget.profile.copyWith(
      name: _name.text.trim(),
      relayConfigId: relayConfig.id,
      relayHost: relayConfig.relayHost,
      relayPort: relayConfig.relayPort,
      deviceId: _deviceId.text.trim(),
      sessionId: _sessionId.text.trim(),
      relayApiKey: relayConfig.relayApiKey,
      password: _password.text,
      username: _username.text.trim(),
      useTls: relayConfig.useTls,
      allowBadCertificate: relayConfig.allowBadCertificate,
    );
  }

  Future<ConnectionProfile?> _save() async {
    final profile = _profileFromForm();
    if (profile == null || _saving) return null;

    setState(() => _saving = true);
    final saved = await widget.connectionService.save(profile);
    if (mounted) setState(() => _saving = false);
    return saved;
  }

  Future<void> _saveAndClose() async {
    final profile = await _save();
    if (!mounted || profile == null) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _saveAndConnect() async {
    final profile = await _save();
    if (!mounted || profile == null) return;
    await Navigator.of(context).pushReplacement<void, bool>(
      MaterialPageRoute(
        builder: (context) => TerminalPage(
          profile: profile,
          service: widget.terminalService,
          connectionService: widget.connectionService,
          relayService: widget.relayService,
        ),
      ),
      result: true,
    );
  }

  void _applyRelayConfig(String? id) {
    setState(() {
      _selectedRelayConfigId = id;
    });
  }

  RelayConfig? get _selectedRelayConfig {
    for (final relayConfig in _relayConfigs) {
      if (relayConfig.id == _selectedRelayConfigId) return relayConfig;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? '新建连接' : '连接详情'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _Section(
                title: '基础',
                children: [
                  _field(_name, '名称', Icons.label_outline),
                ],
              ),
              _Section(
                title: '接入服务器',
                children: [
                  if (_relayConfigs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text('请先在“中继服务器”里添加服务器'),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedRelayConfigId,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: '选择中继服务器',
                          prefixIcon: Icon(Icons.hub_outlined, size: 20),
                        ),
                        items: _relayConfigs
                            .map(
                              (relayConfig) => DropdownMenuItem(
                                value: relayConfig.id,
                                child: Text(
                                  relayConfig.name.isEmpty
                                      ? '未命名中继服务器'
                                      : relayConfig.name,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _applyRelayConfig,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请选择一个中继服务器';
                          }
                          return null;
                        },
                      ),
                    ),
                ],
              ),
              _Section(
                title: '目标',
                children: [
                  _field(_deviceId, '要连接的设备 ID', Icons.computer_outlined),
                ],
              ),
              _Section(
                title: '认证',
                children: [
                  _field(
                    _password,
                    'SSH 密码',
                    Icons.password_outlined,
                    obscureText: !_showPassword,
                    validator: (_) => null,
                    suffixIcon: IconButton(
                      tooltip: _showPassword ? '隐藏 SSH 密码' : '显示 SSH 密码',
                      onPressed: () {
                        setState(() => _showPassword = !_showPassword);
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
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                initiallyExpanded: false,
                title: Text(
                  '高级',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                children: [
                  _field(
                    _sessionId,
                    '会话 ID',
                    Icons.tag_outlined,
                    validator: (_) => null,
                  ),
                  _field(
                    _username,
                    '用户名',
                    Icons.person_outline,
                    validator: (_) => null,
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
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _saveAndClose,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('保存'),
                ),
              ),
              if (widget.showConnectAction) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveAndConnect,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('连接'),
                  ),
                ),
              ],
            ],
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
