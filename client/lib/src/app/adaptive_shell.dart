import 'package:flutter/material.dart';

import '../agent/services/agent_service.dart';
import '../agent/ui/agent_page.dart';
import '../core/bridge/core_bridge.dart';
import '../controller/ui/connections_page.dart';
import '../controller/ui/desktop_workspace.dart';
import '../shared/ui/relay_page.dart';

class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({
    required this.bridge,
    super.key,
  });

  final CoreBridge bridge;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return DesktopWorkspace(bridge: bridge);
        }
        return _MobileShell(bridge: bridge);
      },
    );
  }
}

class _MobileShell extends StatefulWidget {
  const _MobileShell({required this.bridge});

  final CoreBridge bridge;

  @override
  State<_MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<_MobileShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ConnectionsPage(bridge: widget.bridge),
      AgentPage(
        service: AgentService(bridge: widget.bridge),
      ),
      const RelayPage(),
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
