import 'package:flutter/material.dart';

import 'adaptive_shell.dart';
import '../core/bridge/core_bridge.dart';

class RemoteTerminalApp extends StatelessWidget {
  const RemoteTerminalApp({
    this.bridge = const RustCoreBridge(),
    super.key,
  });

  final CoreBridge bridge;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remote Terminal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff1c7f6e),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xff0b0f12),
        useMaterial3: true,
      ),
      home: AdaptiveShell(bridge: bridge),
    );
  }
}
