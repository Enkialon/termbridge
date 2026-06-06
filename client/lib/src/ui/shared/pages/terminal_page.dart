import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../../../application/connection/connection_service.dart';
import '../../../application/connection/terminal_service.dart';
import '../../../application/relay/relay_service.dart';
import '../../../domain/connection/entities/connection_profile.dart';
import '../../../domain/connection/ports/terminal_port.dart';
import 'connection_editor_page.dart';

class TerminalPage extends StatefulWidget {
  const TerminalPage({
    required this.profile,
    required this.service,
    this.connectionService,
    this.relayService,
    this.embedded = false,
    super.key,
  });

  final ConnectionProfile profile;
  final TerminalService service;
  final ConnectionService? connectionService;
  final RelayService? relayService;
  final bool embedded;

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final _terminal = Terminal();

  TerminalSessionHandle? _session;
  StreamSubscription<String>? _outputSubscription;
  bool _connecting = false;
  bool _connected = false;
  String _status = '未连接';
  String? _relayLabel;

  @override
  void initState() {
    super.initState();
    _terminal.write('TH 远程终端\r\n');
    _terminal.write('正在连接 ${widget.profile.name}...\r\n');
    unawaited(_loadRelayLabel());
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
  }

  Future<void> _loadRelayLabel() async {
    try {
      final relayLabel =
          await widget.service.describeRelay(widget.profile.relayConfigId);
      if (mounted) setState(() => _relayLabel = relayLabel);
    } catch (_) {
      if (mounted) setState(() => _relayLabel = widget.profile.relayConfigId);
    }
  }

  Future<void> _connect() async {
    if (_connecting || _connected) return;

    setState(() {
      _connecting = true;
      _status = '连接中';
    });

    try {
      final session = await widget.service.open(widget.profile);
      if (!mounted) return;

      _terminal.buffer.clear();
      _terminal.buffer.setCursor(0, 0);
      _terminal.onOutput = _sendText;
      _terminal.onResize = (cols, rows, pixelWidth, pixelHeight) {
        unawaited(session.resize(cols, rows, pixelWidth, pixelHeight));
      };
      _outputSubscription = session.output
          .transform(utf8.decoder)
          .listen(_terminal.write, onError: _handleOutputError, onDone: () {
        if (!mounted) return;
        setState(() {
          _session = null;
          _connected = false;
          _status = '未连接';
        });
      });

      setState(() {
        _session = session;
        _connected = true;
        _status = '已连接';
      });
    } catch (error) {
      _terminal.write('\r\n连接失败: $error\r\n');
      if (!mounted) return;
      setState(() {
        _status = '失败';
      });
    } finally {
      if (mounted) {
        setState(() {
          _connecting = false;
        });
      }
    }
  }

  Future<void> _disconnect() async {
    final session = _session;
    final outputSubscription = _outputSubscription;
    setState(() {
      _session = null;
      _outputSubscription = null;
      _connected = false;
      _status = '未连接';
    });
    _terminal.onOutput = null;
    _terminal.onResize = null;
    await outputSubscription?.cancel();
    await session?.close();
  }

  void _sendText(String data) {
    final session = _session;
    if (session == null) return;
    unawaited(session.write(utf8.encode(data)));
  }

  void _handleOutputError(Object error, StackTrace stackTrace) {
    _terminal.write('\r\nSession error: $error\r\n');
    if (!mounted) return;
    setState(() {
      _session = null;
      _connected = false;
      _status = '失败';
    });
  }

  Future<void> _reconnect() async {
    await _disconnect();
    _terminal.write('\r\n正在重连...\r\n');
    await _connect();
  }

  Future<void> _editConnection() async {
    if (widget.embedded) return;
    final connectionService = widget.connectionService;
    final relayService = widget.relayService;
    if (connectionService == null || relayService == null) return;
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(
        builder: (context) => ConnectionEditorPage(
          profile: widget.profile,
          isNew: false,
          connectionService: connectionService,
          relayService: relayService,
          terminalService: widget.service,
        ),
      ),
    );
  }

  void _showSessionSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.profile.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_relayLabel ?? widget.profile.relayConfigId} · '
                  '${widget.profile.deviceId} · ${widget.profile.sessionId}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_connected ? Icons.link : Icons.link_off),
                  title: Text(_status),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.refresh),
                  title: const Text('重连'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _reconnect();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('编辑连接'),
                  enabled: widget.connectionService != null &&
                      widget.relayService != null,
                  onTap: () {
                    Navigator.of(context).pop();
                    _editConnection();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _terminal.onOutput = null;
    _terminal.onResize = null;
    final outputSubscription = _outputSubscription;
    final session = _session;
    if (outputSubscription != null) {
      unawaited(outputSubscription.cancel());
    }
    if (session != null) {
      unawaited(session.close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final compact = shortest < 520;

    final content = SafeArea(
      top: !widget.embedded,
      child: Column(
        children: [
          _SessionBar(
            profile: widget.profile,
            relayLabel: _relayLabel,
            status: _status,
            connecting: _connecting,
            connected: _connected,
            onTap: _showSessionSheet,
          ),
          if (!widget.embedded)
            _ShortcutBar(
              enabled: _connected,
              onSend: _sendText,
            ),
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(color: Color(0xff050708)),
              child: TerminalView(
                _terminal,
                autofocus: true,
                padding: const EdgeInsets.all(8),
                textStyle: TerminalStyle(
                  fontSize: compact ? 13 : 14,
                  fontFamily: 'monospace',
                ),
                theme: _terminalTheme(),
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return Column(
        children: [
          _EmbeddedTerminalToolbar(
            profile: widget.profile,
            relayLabel: _relayLabel,
            status: _status,
            connecting: _connecting,
            connected: _connected,
            onConnect: _connect,
            onDisconnect: _disconnect,
            onClear: () {
              _terminal.buffer.clear();
              _terminal.buffer.setCursor(0, 0);
            },
          ),
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: _showSessionSheet,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: _connected ? '断开' : '重连',
            onPressed: _connecting
                ? null
                : _connected
                    ? _disconnect
                    : _connect,
            icon: Icon(_connected ? Icons.link_off : Icons.play_arrow),
          ),
          IconButton(
            tooltip: '清屏',
            onPressed: () {
              _terminal.buffer.clear();
              _terminal.buffer.setCursor(0, 0);
            },
            icon: const Icon(Icons.cleaning_services_outlined),
          ),
          IconButton(
            tooltip: '连接详情',
            onPressed:
                widget.connectionService == null || widget.relayService == null
                    ? null
                    : _editConnection,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: content,
    );
  }

  TerminalTheme _terminalTheme() {
    return TerminalTheme(
      cursor: const Color(0xfff2f5f3),
      selection: const Color(0x6637a58c),
      foreground: const Color(0xffd7e0dc),
      background: const Color(0xff050708),
      black: const Color(0xff111417),
      red: const Color(0xffe06c75),
      green: const Color(0xff70c082),
      yellow: const Color(0xffd6b15d),
      blue: const Color(0xff61afef),
      magenta: const Color(0xffc678dd),
      cyan: const Color(0xff56b6c2),
      white: const Color(0xffd7e0dc),
      brightBlack: const Color(0xff5c6670),
      brightRed: const Color(0xffff7b86),
      brightGreen: const Color(0xff8bdc9d),
      brightYellow: const Color(0xffffd16d),
      brightBlue: const Color(0xff7bc7ff),
      brightMagenta: const Color(0xffdc91f2),
      brightCyan: const Color(0xff7bdbe4),
      brightWhite: const Color(0xffffffff),
      searchHitBackground: const Color(0xff806600),
      searchHitBackgroundCurrent: const Color(0xffa87800),
      searchHitForeground: const Color(0xffffffff),
    );
  }
}

class _EmbeddedTerminalToolbar extends StatelessWidget {
  const _EmbeddedTerminalToolbar({
    required this.profile,
    required this.relayLabel,
    required this.status,
    required this.connecting,
    required this.connected,
    required this.onConnect,
    required this.onDisconnect,
    required this.onClear,
  });

  final ConnectionProfile profile;
  final String? relayLabel;
  final String status;
  final bool connecting;
  final bool connected;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xff0d1215),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Icon(Icons.terminal, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    relayLabel == null ? status : '$relayLabel · $status',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: connected ? '断开' : '连接',
              onPressed: connecting
                  ? null
                  : connected
                      ? onDisconnect
                      : onConnect,
              icon: Icon(connected ? Icons.link_off : Icons.play_arrow),
            ),
            IconButton(
              tooltip: '清屏',
              onPressed: onClear,
              icon: const Icon(Icons.cleaning_services_outlined),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _SessionBar extends StatelessWidget {
  const _SessionBar({
    required this.profile,
    required this.relayLabel,
    required this.status,
    required this.connecting,
    required this.connected,
    required this.onTap,
  });

  final ConnectionProfile profile;
  final String? relayLabel;
  final String status;
  final bool connecting;
  final bool connected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = connected
        ? const Color(0xff70c082)
        : connecting
            ? const Color(0xffd6b15d)
            : Theme.of(context).colorScheme.onSurfaceVariant;

    return Material(
      color: const Color(0xff10161a),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            children: [
              Icon(Icons.circle, color: color, size: 10),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${relayLabel ?? profile.relayConfigId} · '
                  '${profile.deviceId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                status,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutBar extends StatelessWidget {
  const _ShortcutBar({
    required this.enabled,
    required this.onSend,
  });

  final bool enabled;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xff0d1215),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            _key('Esc', '\x1b'),
            _key('Tab', '\t'),
            _key('Ctrl+C', '\x03'),
            _key('Ctrl+D', '\x04'),
            _key('↑', '\x1b[A'),
            _key('↓', '\x1b[B'),
            _key('←', '\x1b[D'),
            _key('→', '\x1b[C'),
            _key('/', '/'),
            _key('-', '-'),
            _key('~', '~'),
          ],
        ),
      ),
    );
  }

  Widget _key(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton(
        onPressed: enabled ? () => onSend(value) : null,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 36),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: Text(label),
      ),
    );
  }
}
