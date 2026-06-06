import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_remote_terminal/src/app/app.dart';
import 'package:mobile_remote_terminal/src/app/app_services.dart';
import 'package:mobile_remote_terminal/src/infrastructure/rust/rust_core_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders the app shell', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      RemoteTerminalApp(
        services: AppServices.create(
          runtime: const UnsupportedRustCoreBridge(),
          terminalPort: const UnsupportedRustCoreBridge(),
        ),
      ),
    );

    expect(find.text('会话'), findsWidgets);
  });
}
