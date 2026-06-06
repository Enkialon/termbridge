import 'package:flutter/material.dart';

import 'adaptive_shell.dart';
import 'app_services.dart';

class RemoteTerminalApp extends StatelessWidget {
  const RemoteTerminalApp({
    required this.services,
    super.key,
  });

  final AppServices services;

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
      home: AdaptiveShell(services: services),
    );
  }
}
