import 'package:flutter/material.dart';

import 'src/app/app.dart';
import 'src/app/app_services.dart';
import 'src/infrastructure/rust/generated_frb_core_api.dart';
import 'src/infrastructure/rust/rust_core_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = await GeneratedFrbCoreApi.create();
  final bridge = RustCoreBridge(api: api);
  runApp(
    RemoteTerminalApp(
      services: AppServices.defaults(
        runtime: bridge,
        terminalPort: bridge,
      ),
    ),
  );
}
