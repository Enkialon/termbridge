import 'package:flutter/material.dart';

import '../../core/bridge/core_bridge.dart';
import '../../shared/storage/profile_store.dart';
import '../models/connection_profile.dart';
import 'connection_editor_page.dart';
import 'terminal_page.dart';

class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({
    required this.bridge,
    super.key,
  });

  final CoreBridge bridge;

  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage> {
  final _store = ProfileStore();
  late Future<List<ConnectionProfile>> _profiles;

  @override
  void initState() {
    super.initState();
    _profiles = _store.loadAll();
  }

  void _reload() {
    setState(() {
      _profiles = _store.loadAll();
    });
  }

  Future<void> _openEditor([ConnectionProfile? profile]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ConnectionEditorPage(
          profile: profile ?? _store.createProfile(),
          isNew: profile == null,
          bridge: widget.bridge,
        ),
      ),
    );
    if (saved == true) _reload();
  }

  Future<void> _openTerminal(ConnectionProfile profile) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => TerminalPage(
          profile: profile,
          bridge: widget.bridge,
        ),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('会话'),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '新建连接',
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: FutureBuilder<List<ConnectionProfile>>(
          future: _profiles,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final profiles = snapshot.data!;
            if (profiles.isEmpty) {
              return _EmptyConnections(onCreate: () => _openEditor());
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              itemCount: profiles.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final profile = profiles[index];
                return _ConnectionTile(
                  profile: profile,
                  onConnect: () => _openTerminal(profile),
                  onEdit: () => _openEditor(profile),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ConnectionTile extends StatelessWidget {
  const _ConnectionTile({
    required this.profile,
    required this.onConnect,
    required this.onEdit,
  });

  final ConnectionProfile profile;
  final VoidCallback onConnect;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: const Color(0xff11181c),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onConnect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.terminal, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${profile.relayHost}:${profile.relayPort} · '
                      '${profile.deviceId} · ${profile.sessionId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onConnect,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('连接'),
              ),
              IconButton(
                tooltip: '编辑',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyConnections extends StatelessWidget {
  const _EmptyConnections({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: onCreate,
        icon: const Icon(Icons.add),
        label: const Text('新建连接'),
      ),
    );
  }
}
