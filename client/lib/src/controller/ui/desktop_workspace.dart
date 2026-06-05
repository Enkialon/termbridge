import 'package:flutter/material.dart';

import '../../agent/models/agent_config.dart';
import '../../agent/models/agent_status.dart';
import '../../agent/services/agent_runtime_coordinator.dart';
import '../../agent/services/agent_service.dart';
import '../../core/bridge/core_bridge.dart';
import '../../shared/storage/agent_config_store.dart';
import '../../shared/storage/profile_store.dart';
import '../../shared/storage/service_group_store.dart';
import '../../shared/services/relay_config_service.dart';
import '../models/connection_profile.dart';
import 'connection_editor_page.dart';
import 'terminal_page.dart';

class DesktopWorkspace extends StatefulWidget {
  const DesktopWorkspace({
    required this.bridge,
    super.key,
  });

  final CoreBridge bridge;

  @override
  State<DesktopWorkspace> createState() => _DesktopWorkspaceState();
}

class _DesktopWorkspaceState extends State<DesktopWorkspace> {
  final _store = ProfileStore();
  late final AgentService _agentService = AgentService(bridge: widget.bridge);
  late Future<List<ConnectionProfile>> _profiles = _store.loadAll();
  ConnectionProfile? _selectedProfile;
  var _section = _DesktopSection.connections;

  void _reload() {
    setState(() {
      _profiles = _store.loadAll();
    });
  }

  Future<void> _edit([ConnectionProfile? profile]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog.fullscreen(
          child: ConnectionEditorPage(
            profile: profile ?? _store.createProfile(),
            isNew: profile == null,
            bridge: widget.bridge,
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
          switch (_section) {
            _DesktopSection.connections => Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 320,
                      child: _ConnectionPane(
                        profiles: _profiles,
                        selectedProfile: _selectedProfile,
                        onOpen: _open,
                        onEdit: _edit,
                        onCreate: () => _edit(),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _TerminalPane(
                        bridge: widget.bridge,
                        profile: _selectedProfile,
                      ),
                    ),
                  ],
                ),
              ),
            _DesktopSection.agent => Expanded(
                child: _AgentPane(service: _agentService),
              ),
            _DesktopSection.services => const Expanded(
                child: _RelayPane(),
              ),
          },
        ],
      ),
    );
  }
}

enum _DesktopSection {
  connections,
  agent,
  services,
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
            icon: Icon(Icons.devices_outlined),
            selectedIcon: Icon(Icons.devices),
            label: Text('本机'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.hub_outlined),
            selectedIcon: Icon(Icons.hub),
            label: Text('中继服务器'),
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
    required this.onCreate,
  });

  final Future<List<ConnectionProfile>> profiles;
  final ConnectionProfile? selectedProfile;
  final ValueChanged<ConnectionProfile> onOpen;
  final ValueChanged<ConnectionProfile> onEdit;
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
                        '${profile.relayHost}:${profile.relayPort}  ${profile.deviceId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      leading: const Icon(Icons.terminal),
                      trailing: IconButton(
                        tooltip: '编辑',
                        onPressed: () => onEdit(profile),
                        icon: const Icon(Icons.edit_outlined),
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
    required this.bridge,
    required this.profile,
  });

  final CoreBridge bridge;
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
      bridge: bridge,
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

class _AgentPaneState extends State<_AgentPane> {
  late final AgentRuntimeCoordinator _coordinator = AgentRuntimeCoordinator(
    service: widget.service,
  );
  final _formKey = GlobalKey<FormState>();
  final _deviceId = TextEditingController();
  final _shell = TextEditingController();
  var _groups = <ServiceGroup>[];
  String? _selectedGroupId;
  var _busy = false;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = await _coordinator.load();
    if (!mounted) return;
    final selectedGroupId =
        state.groups.any((group) => group.id == state.settings.serviceGroupId)
            ? state.settings.serviceGroupId
            : null;
    setState(() {
      _deviceId.text = state.settings.deviceId;
      _shell.text = state.settings.shell;
      _groups = state.groups;
      _selectedGroupId = selectedGroupId;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _deviceId.dispose();
    _shell.dispose();
    super.dispose();
  }

  AgentSettings? _settingsFromForm() {
    if (!_formKey.currentState!.validate()) return null;
    return AgentSettings(
      deviceId: _deviceId.text.trim(),
      shell: _shell.text.trim(),
      serviceGroupId: _selectedGroupId,
    );
  }

  Future<AgentSettings?> _save({bool showMessage = true}) async {
    final settings = _settingsFromForm();
    if (settings == null) return null;
    await _coordinator.saveSettings(settings);
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
    final config = _agentConfig(settings);
    if (config == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择一个中继服务器')),
      );
      return;
    }
    await _run(() => _coordinator.start(config));
  }

  AgentConfig? _agentConfig(AgentSettings settings) {
    return _coordinator.resolveConfig(settings: settings, groups: _groups);
  }

  Future<void> _stop() => _run(_coordinator.stop);

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
      stream: _coordinator.watchStatus(),
      initialData: AgentStatus.stopped(),
      builder: (context, snapshot) {
        final status = snapshot.data ?? AgentStatus.stopped();
        final online = status.kind == AgentStatusKind.online ||
            status.kind == AgentStatusKind.connecting;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('本机', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 18),
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
                  const SizedBox(height: 18),
                  _field(_deviceId, '设备 ID', Icons.computer_outlined),
                  _field(_shell, 'Shell', Icons.terminal_outlined),
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
  const _RelayPane();

  @override
  State<_RelayPane> createState() => _RelayPaneState();
}

class _RelayPaneState extends State<_RelayPane> {
  final _service = RelayConfigService();
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController(text: '8080');
  final _token = TextEditingController();
  var _groups = <ServiceGroup>[];
  ServiceGroup? _selected;
  var _useTls = false;
  var _allowBadCertificate = false;
  var _showToken = false;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final groups = await _service.loadAll();
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
      _port.text = '8080';
      _token.clear();
      _useTls = false;
      _allowBadCertificate = false;
    });
  }

  void _select(ServiceGroup group) {
    setState(() {
      _selected = group;
      _name.text = group.name;
      _host.text = group.relayHost;
      _port.text = group.relayPort.toString();
      _token.text = group.token;
      _useTls = group.useTls;
      _allowBadCertificate = group.allowBadCertificate;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final saved = await _service.save(
      RelayConfigInput(
        selected: _selected,
        name: _name.text.trim(),
        host: _host.text.trim(),
        port: int.parse(_port.text.trim()),
        token: _token.text,
        useTls: _useTls,
        allowBadCertificate: _allowBadCertificate,
      ),
    );
    await _load();
    final reloaded = _groups.where((group) => group.id == saved.id);
    if (reloaded.isNotEmpty) _select(reloaded.first);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('中继服务器已保存')),
      );
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

    await _service.setAsAgentRelay(selected);
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
    _token.dispose();
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
                            child: ListTile(
                              selected: selected,
                              leading: const Icon(Icons.hub_outlined),
                              title: Text(
                                group.name.isEmpty ? '未命名中继服务器' : group.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                group.relayHost.isEmpty
                                    ? '未配置地址'
                                    : '${group.relayHost}:${group.relayPort}',
                              ),
                              onTap: () => _select(group),
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
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('保存'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _selected == null ? null : _setAsAgentRelay,
                      icon: const Icon(Icons.devices_outlined),
                      label: const Text('设为本机中继服务器'),
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
