import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../application/agent/agent_service.dart';
import '../../application/connection/terminal_service.dart';
import '../../application/relay/relay_service.dart';
import '../../domain/agent/entities/agent_settings.dart';
import '../../domain/agent/entities/agent_status.dart';
import '../../domain/connection/entities/connection_profile.dart';
import '../../domain/relay/entities/relay_config.dart';
import '../shared/pages/connection_editor_page.dart';
import '../shared/pages/terminal_page.dart';

class DesktopWorkspace extends StatefulWidget {
  const DesktopWorkspace({
    required this.services,
    super.key,
  });

  final AppServices services;

  @override
  State<DesktopWorkspace> createState() => _DesktopWorkspaceState();
}

class _DesktopWorkspaceState extends State<DesktopWorkspace> {
  late Future<List<ConnectionProfile>> _profiles =
      widget.services.connections.loadAll();
  late final Widget _agentPane;
  ConnectionProfile? _selectedProfile;
  var _section = _DesktopSection.connections;

  @override
  void initState() {
    super.initState();
    _agentPane = _AgentPane(service: widget.services.agent);
  }

  void _reload() {
    setState(() {
      _profiles = widget.services.connections.loadAll();
    });
  }

  Future<void> _edit([ConnectionProfile? profile]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog.fullscreen(
          child: ConnectionEditorPage(
            profile: profile ?? widget.services.connections.createProfile(),
            isNew: profile == null,
            connectionService: widget.services.connections,
            relayService: widget.services.relay,
            terminalService: widget.services.terminal,
            showConnectAction: false,
          ),
        );
      },
    );
    if (saved == true) _reload();
  }

  void _open(ConnectionProfile profile) {
    setState(() {
      _selectedProfile = profile;
      _section = _DesktopSection.connections;
    });
  }

  Future<void> _delete(ConnectionProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除会话'),
          content: Text('确定删除“${profile.name}”吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await widget.services.connections.delete(profile);
    if (!mounted) return;
    setState(() {
      if (_selectedProfile?.id == profile.id) _selectedProfile = null;
      _profiles = widget.services.connections.loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _DesktopNav(
            section: _section,
            onChange: (section) {
              setState(() {
                _section = section;
              });
            },
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              index: _section.index,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 320,
                      child: _ConnectionPane(
                        profiles: _profiles,
                        selectedProfile: _selectedProfile,
                        onOpen: _open,
                        onEdit: _edit,
                        onDelete: _delete,
                        onCreate: () => _edit(),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _TerminalPane(
                        terminalService: widget.services.terminal,
                        profile: _selectedProfile,
                      ),
                    ),
                  ],
                ),
                _RelayPane(service: widget.services.relay),
                _agentPane,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _DesktopSection {
  connections,
  services,
  agent,
}

class _DesktopNav extends StatelessWidget {
  const _DesktopNav({
    required this.section,
    required this.onChange,
  });

  final _DesktopSection section;
  final ValueChanged<_DesktopSection> onChange;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return NavigationRailTheme(
      data: NavigationRailThemeData(
        backgroundColor: const Color(0xff0b0f12),
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        selectedIconTheme: IconThemeData(color: scheme.primary, size: 24),
        unselectedIconTheme: IconThemeData(
          color: scheme.onSurfaceVariant,
          size: 23,
        ),
        selectedLabelTextStyle:
            Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
        unselectedLabelTextStyle:
            Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
      ),
      child: NavigationRail(
        selectedIndex: section.index,
        onDestinationSelected: (index) {
          onChange(_DesktopSection.values[index]);
        },
        labelType: NavigationRailLabelType.all,
        minWidth: 86,
        destinations: const [
          NavigationRailDestination(
            icon: Icon(Icons.terminal_outlined),
            selectedIcon: Icon(Icons.terminal),
            label: Text('会话'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.hub_outlined),
            selectedIcon: Icon(Icons.hub),
            label: Text('中继服务器'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.devices_outlined),
            selectedIcon: Icon(Icons.devices),
            label: Text('本机'),
          ),
        ],
      ),
    );
  }
}

class _ConnectionPane extends StatelessWidget {
  const _ConnectionPane({
    required this.profiles,
    required this.selectedProfile,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onCreate,
  });

  final Future<List<ConnectionProfile>> profiles;
  final ConnectionProfile? selectedProfile;
  final ValueChanged<ConnectionProfile> onOpen;
  final ValueChanged<ConnectionProfile> onEdit;
  final ValueChanged<ConnectionProfile> onDelete;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '连接',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: '新建连接',
                onPressed: onCreate,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<ConnectionProfile>>(
            future: profiles,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final values = snapshot.data!;
              if (values.isEmpty) {
                return Center(
                  child: FilledButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add),
                    label: const Text('新建连接'),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                itemCount: values.length,
                separatorBuilder: (context, index) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final profile = values[index];
                  final selected = selectedProfile?.id == profile.id;
                  return Material(
                    color: selected
                        ? Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.48)
                        : const Color(0xff11181c),
                    borderRadius: BorderRadius.circular(8),
                    child: ListTile(
                      selected: selected,
                      title: Text(
                        profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${profile.relayConfigId}  ${profile.deviceId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      leading: const Icon(Icons.terminal),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: '编辑',
                            onPressed: () => onEdit(profile),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: '删除',
                            onPressed: () => onDelete(profile),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                      onTap: () => onOpen(profile),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TerminalPane extends StatelessWidget {
  const _TerminalPane({
    required this.terminalService,
    required this.profile,
  });

  final TerminalService terminalService;
  final ConnectionProfile? profile;

  @override
  Widget build(BuildContext context) {
    final value = profile;
    if (value == null) {
      return const Center(
        child: Text('选择一个连接'),
      );
    }
    return TerminalPage(
      key: ValueKey(value.id),
      profile: value,
      service: terminalService,
      embedded: true,
    );
  }
}

class _AgentPane extends StatefulWidget {
  const _AgentPane({required this.service});

  final AgentService service;

  @override
  State<_AgentPane> createState() => _AgentPaneState();
}

String _agentStatusTitle(AgentStatus status) {
  return switch (status.kind) {
    AgentStatusKind.stopped => '未启动',
    AgentStatusKind.connecting => '启动中',
    AgentStatusKind.online => '已启动',
    AgentStatusKind.error => '启动失败',
    AgentStatusKind.unsupported => '当前平台不支持',
  };
}

String _agentStatusMessage(AgentStatus status) {
  final message = status.message;
  if (message != null && message.isNotEmpty) return message;
  return switch (status.kind) {
    AgentStatusKind.stopped => '启动后，其他设备可以通过中继连接到本机',
    AgentStatusKind.connecting => '正在连接中继服务器',
    AgentStatusKind.online => '本机已允许远程控制',
    AgentStatusKind.error => '请检查中继服务器和本机配置',
    AgentStatusKind.unsupported => '当前平台暂不支持远程控制',
  };
}

class _AgentPaneState extends State<_AgentPane> {
  final _formKey = GlobalKey<FormState>();
  final _deviceId = TextEditingController();
  final _shell = TextEditingController();
  final _password = TextEditingController();
  var _groups = <RelayConfig>[];
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
    final selectedGroupId = state.relayConfigs.any(
      (group) => group.id == state.settings.relayConfigId,
    )
        ? state.settings.relayConfigId
        : null;
    setState(() {
      _deviceId.text = state.settings.deviceId;
      _shell.text = state.settings.shell;
      _password.text = state.settings.password;
      _groups = state.relayConfigs;
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
      relayConfigId: _selectedGroupId,
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
    if (!mounted) return;
    if (settings == null) return;
    await _run(() => widget.service.start(settings));
  }

  Future<void> _stop() => _run(widget.service.stop);

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<AgentStatus>(
      stream: widget.service.watchStatus(),
      initialData: AgentStatus.stopped(),
      builder: (context, snapshot) {
        final status = snapshot.data ?? AgentStatus.stopped();
        final online = status.kind == AgentStatusKind.online ||
            status.kind == AgentStatusKind.connecting;
        final statusTitle = _agentStatusTitle(status);
        final statusMessage = _agentStatusMessage(status);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('远程控制设置',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 18),
                  Text('允许被远程控制',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      online ? Icons.link : Icons.link_off,
                      color: online
                          ? const Color(0xff70c082)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    title: Text(statusTitle),
                    subtitle: Text(statusMessage),
                  ),
                  const SizedBox(height: 18),
                  Text('本机信息', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 6),
                  Text('中继服务器', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
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
                                  group.name.isEmpty ? '未命名中继服务器' : group.name,
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
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy || online ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('保存'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: _busy || online || _selectedGroupId == null
                            ? null
                            : _start,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('启动'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _busy || !online ? null : _stop,
                        icon: const Icon(Icons.stop),
                        label: const Text('停止'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

class _RelayPane extends StatefulWidget {
  const _RelayPane({required this.service});

  final RelayService service;

  @override
  State<_RelayPane> createState() => _RelayPaneState();
}

class _RelayPaneState extends State<_RelayPane> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController();
  final _relayApiKey = TextEditingController();
  var _groups = <RelayConfig>[];
  RelayConfig? _selected;
  final _testing = <String>{};
  var _useTls = false;
  var _allowBadCertificate = false;
  var _showRelayApiKey = false;
  var _loaded = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final groups = await widget.service.loadAll();
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _loaded = true;
    });
    if (groups.isNotEmpty) _select(groups.first);
  }

  void _create() {
    setState(() {
      _selected = null;
      _name.clear();
      _host.clear();
      _port.clear();
      _relayApiKey.clear();
      _useTls = false;
      _allowBadCertificate = false;
    });
  }

  void _select(RelayConfig group) {
    setState(() {
      _selected = group;
      _name.text = group.name;
      _host.text = group.relayHost;
      _port.text = group.relayPort.toString();
      _relayApiKey.text = group.relayApiKey;
      _useTls = group.useTls;
      _allowBadCertificate = group.allowBadCertificate;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.service.save(
        RelayConfigInput(
          selected: _selected,
          name: _name.text.trim(),
          host: _host.text.trim(),
          port: int.parse(_port.text.trim()),
          relayApiKey: _relayApiKey.text,
          useTls: _useTls,
          allowBadCertificate: _allowBadCertificate,
        ),
      );
      await _load();
      final reloaded = _groups.where((group) => group.id == saved.id);
      if (reloaded.isNotEmpty) _select(reloaded.first);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_relaySaveMessage(saved))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test(RelayConfig group) async {
    if (_testing.contains(group.id)) return;
    setState(() => _testing.add(group.id));
    try {
      final tested = await widget.service.test(group);
      if (!mounted) return;
      setState(() {
        _groups = _groups
            .map((value) => value.id == tested.id ? tested : value)
            .toList();
        if (_selected?.id == tested.id) {
          _selected = tested;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _testing.remove(group.id));
      }
    }
  }

  Future<void> _setAsAgentRelay() async {
    final selected = _selected;
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择一个中继服务器')),
      );
      return;
    }

    await widget.service.setAsAgentRelay(selected);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已设为本机中继服务器')),
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _relayApiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return Row(
      children: [
        SizedBox(
          width: 320,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '中继服务器',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: '新建中继服务器',
                      onPressed: _create,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _groups.isEmpty
                    ? Center(
                        child: FilledButton.icon(
                          onPressed: _create,
                          icon: const Icon(Icons.add),
                          label: const Text('新建中继服务器'),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                        itemCount: _groups.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final group = _groups[index];
                          final selected = _selected?.id == group.id;
                          return Material(
                            color: selected
                                ? Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.48)
                                : const Color(0xff11181c),
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _select(group),
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 10, 12),
                                child: Row(
                                  children: [
                                    const Icon(Icons.hub_outlined),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
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
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('中继服务器配置',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 18),
                    _field(_name, '中继服务器名称', Icons.label_outline),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _field(_host, '服务器地址', Icons.dns_outlined),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(
                            _port,
                            '端口',
                            Icons.numbers,
                            keyboardType: TextInputType.number,
                            validator: _validatePort,
                          ),
                        ),
                      ],
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
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: const Text('保存'),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: OutlinedButton.icon(
                            onPressed:
                                _selected == null ? null : _setAsAgentRelay,
                            icon: const Icon(Icons.devices_outlined),
                            label: const Text(
                              '设为本机中继服务器',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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

String _relaySaveMessage(RelayConfig group) {
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
