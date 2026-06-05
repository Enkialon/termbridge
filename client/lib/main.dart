import 'package:flutter/material.dart';

import 'src/app/app.dart';
import 'src/core/bridge/core_bridge.dart';
import 'src/core/bridge/generated_frb_core_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = await GeneratedFrbCoreApi.create();
  runApp(
    RemoteTerminalApp(
      bridge: RustCoreBridge(api: api),
    ),
  );
}
