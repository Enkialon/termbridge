import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_remote_terminal/src/app/app.dart';
import 'package:mobile_remote_terminal/src/core/bridge/core_bridge.dart';

void main() {
  testWidgets('renders the app shell', (tester) async {
    await tester.pumpWidget(
      const RemoteTerminalApp(
        bridge: UnsupportedCoreBridge(),
      ),
    );

    expect(find.text('Connections'), findsWidgets);
  });
}
