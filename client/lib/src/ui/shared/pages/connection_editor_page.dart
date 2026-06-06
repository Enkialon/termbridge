import 'package:flutter/material.dart';

import '../../../application/connection/connection_service.dart';
import '../../../application/connection/terminal_service.dart';
import '../../../application/relay/relay_service.dart';
import '../../../domain/connection/entities/connection_profile.dart';
import '../../../domain/relay/entities/service_group.dart';
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
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _deviceId;
  late final TextEditingController _sessionId;
  late final TextEditingController _token;
  late final TextEditingController _username;

  late bool _useTls;
  late bool _allowBadCertificate;
  var _serviceGroups = <ServiceGroup>[];
  String? _selectedServiceGroupId;
  bool _showToken = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _name = TextEditingController(text: profile.name);
    _host = TextEditingController(text: profile.relayHost);
    _port = TextEditingController(
      text: profile.relayPort <= 0 ? '' : profile.relayPort.toString(),
    );
    _deviceId = TextEditingController(text: profile.deviceId);
    _sessionId = TextEditingController(text: profile.sessionId);
    _token = TextEditingController(text: profile.token);
    _username = TextEditingController(text: profile.username);
    _useTls = profile.useTls;
    _allowBadCertificate = profile.allowBadCertificate;
    _loadServiceGroups();
  }

  Future<void> _loadServiceGroups() async {
    final groups = await widget.relayService.loadAll();
    if (!mounted) return;
    String? selectedGroupId;
    final relayPort = int.tryParse(_port.text.trim());
    for (final group in groups) {
      if (group.relayHost == _host.text.trim() &&
          group.relayPort == relayPort) {
        selectedGroupId = group.id;
        break;
      }
    }
    setState(() {
      _serviceGroups = groups;
      _selectedServiceGroupId = selectedGroupId;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _deviceId.dispose();
    _sessionId.dispose();
    _token.dispose();
    _username.dispose();
    super.dispose();
  }

  ConnectionProfile? _profileFromForm() {
    if (!_formKey.currentState!.validate()) return null;
    final sessionId = _sessionId.text.trim();
    return widget.profile.copyWith(
      name: _name.text.trim(),
      relayHost: _host.text.trim(),
      relayPort: int.parse(_port.text.trim()),
      deviceId: _deviceId.text.trim(),
      sessionId: sessionId.isEmpty
          ? 'session-${DateTime.now().microsecondsSinceEpoch}'
          : sessionId,
      token: _token.text,
      username: _username.text.trim(),
      useTls: _useTls,
      allowBadCertificate: _useTls && _allowBadCertificate,
    );
  }

  Future<ConnectionProfile?> _save() async {
    final profile = _profileFromForm();
    if (profile == null || _saving) return null;

    setState(() => _saving = true);
    await widget.connectionService.save(profile);
    if (mounted) setState(() => _saving = false);
    return profile;
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

  Future<void> _saveCurrentServiceGroup() async {
    final port = int.tryParse(_port.text.trim());
    if (_host.text.trim().isEmpty || port == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填写服务器地址和端口')),
      );
      return;
    }

    await widget.relayService.save(
      RelayConfigInput(
        selected: null,
        name: '${_host.text.trim()}:$port',
        host: _host.text.trim(),
        port: port,
        token: _token.text,
        useTls: _useTls,
        allowBadCertificate: _allowBadCertificate,
      ),
    );
    await _loadServiceGroups();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('中继服务器已保存')),
      );
    }
  }

  void _applyServiceGroup(String? id) {
    ServiceGroup? group;
    for (final value in _serviceGroups) {
      if (value.id == id) {
        group = value;
        break;
      }
    }
    if (group == null) return;
    setState(() {
      _selectedServiceGroupId = id;
      _host.text = group!.relayHost;
      _port.text = group.relayPort.toString();
      _token.text = group.token;
      _useTls = group.useTls;
      _allowBadCertificate = group.allowBadCertificate;
    });
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
                  if (_serviceGroups.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedServiceGroupId,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: '选择中继服务器',
                          prefixIcon: Icon(Icons.hub_outlined, size: 20),
                        ),
                        items: _serviceGroups
                            .map(
                              (group) => DropdownMenuItem(
                                value: group.id,
                                child: Text(
                                  group.name.isEmpty ? '未命名中继服务器' : group.name,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _applyServiceGroup,
                      ),
                    ),
                  _field(_host, '服务器地址', Icons.dns_outlined),
                  _field(
                    _port,
                    '端口',
                    Icons.numbers,
                    keyboardType: TextInputType.number,
                    validator: _validatePort,
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _saveCurrentServiceGroup,
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: const Text('保存为中继服务器'),
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
                    _token,
                    'Token',
                    Icons.key_outlined,
                    obscureText: !_showToken,
                    suffixIcon: IconButton(
                      tooltip: _showToken ? '隐藏 Token' : '显示 Token',
                      onPressed: () {
                        setState(() => _showToken = !_showToken);
                      },
                      icon: Icon(
                        _showToken
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

  String? _validatePort(String? value) {
    final port = int.tryParse(value ?? '');
    if (port == null || port <= 0 || port > 65535) {
      return '请输入 1-65535';
    }
    return null;
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
