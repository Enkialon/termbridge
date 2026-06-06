import 'package:flutter/material.dart';

import '../ui/desktop/desktop_workspace.dart';
import '../ui/mobile/pages/agent_page.dart';
import '../ui/mobile/pages/connections_page.dart';
import '../ui/mobile/pages/relay_page.dart';
import 'app_services.dart';

class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({
    required this.services,
    super.key,
  });

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return DesktopWorkspace(services: services);
        }
        return _MobileShell(services: services);
      },
    );
  }
}

class _MobileShell extends StatefulWidget {
  const _MobileShell({required this.services});

  final AppServices services;

  @override
  State<_MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<_MobileShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ConnectionsPage(
        connectionService: widget.services.connections,
        terminalService: widget.services.terminal,
        relayService: widget.services.relay,
      ),
      AgentPage(service: widget.services.agent),
      RelayPage(service: widget.services.relay),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) {
          setState(() {
            _index = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.terminal_outlined),
            selectedIcon: Icon(Icons.terminal),
            label: '会话',
          ),
          NavigationDestination(
            icon: Icon(Icons.devices_outlined),
            selectedIcon: Icon(Icons.devices),
            label: '本机',
          ),
          NavigationDestination(
            icon: Icon(Icons.hub_outlined),
            selectedIcon: Icon(Icons.hub),
            label: '中继服务器',
          ),
        ],
      ),
    );
  }
}
