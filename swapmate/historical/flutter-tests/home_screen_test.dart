import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swapmate/src/net/game_client.dart';
import 'package:swapmate/src/screens/home_screen.dart';
import 'package:swapmate/src/theme/theme.dart';
import 'package:swapmate/src/widgets/piece_painter.dart';

Widget _home(Brightness brightness, GameClient client, VoidCallback onToggle) =>
    MaterialApp(
      theme: buildTheme(brightness),
      home: HomeScreen(
        client: client,
        initialName: 'Tester',
        initialServer: 'ws://localhost:8787/ws',
        onConnect: (_, _) async {},
        onToggleTheme: onToggle,
      ),
    );

void main() {
  testWidgets('phone theme control remains reachable while scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = GameClient(platform: 'test');
    addTearDown(client.dispose);
    var toggles = 0;
    await tester.pumpWidget(_home(Brightness.dark, client, () => toggles++));
    await tester.pumpAndSettle();

    final theme = find.byTooltip('Light theme');
    final scroll = find.byType(SingleChildScrollView);
    await tester.tap(theme);
    expect(toggles, 1);
    await tester.drag(scroll, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(theme);
    expect(toggles, 2);
    expect(
      tester.getRect(scroll).top,
      greaterThanOrEqualTo(tester.getRect(theme).bottom),
    );
  });

  testWidgets('home screen shows the brand, entry points and join form', (
    tester,
  ) async {
    final client = GameClient(platform: 'test');
    addTearDown(client.dispose);
    await tester.pumpWidget(_home(Brightness.dark, client, () {}));
    await tester.pumpAndSettle();

    expect(find.text('Swapmate'), findsOneWidget);
    expect(find.byType(SwapmateMark), findsWidgets);
    expect(find.text('Create a room'), findsOneWidget);
    expect(find.text('Play with bots'), findsOneWidget);
    expect(find.text('Join'), findsOneWidget);
    expect(find.text('Tester'), findsOneWidget);
  });

  testWidgets('joining without a room code explains the 4-letter code', (
    tester,
  ) async {
    final client = GameClient(platform: 'test');
    addTearDown(client.dispose);
    await tester.pumpWidget(_home(Brightness.light, client, () {}));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Join'));
    await tester.pump();

    expect(find.text('Enter the 4-letter room code'), findsOneWidget);
  });
}
