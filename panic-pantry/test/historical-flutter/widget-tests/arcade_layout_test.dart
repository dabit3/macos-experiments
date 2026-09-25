import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panic_pantry/net/client.dart';
import 'package:panic_pantry/screens/game_screen.dart';
import 'package:panic_pantry/theme/tokens.dart';
import 'package:panic_pantry/widgets/ui.dart';
import 'package:panic_pantry_core/panic_pantry_core.dart';

void main() {
  testWidgets('staggered entrances finish fully visible', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Enter(index: 4, child: Text('Ready'))),
      ),
    );
    await tester.pumpAndSettle();
    final opacity = tester.widget<Opacity>(find.ancestor(of: find.text('Ready'), matching: find.byType(Opacity)).first);
    expect(opacity.opacity, 1);
  });

  testWidgets('focused arcade button activates once for Enter and Space', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: PPButton(label: 'Start', onPressed: () => pressed++),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(pressed, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(pressed, 2);
  });

  testWidgets('landscape touch kitchen stays playable and controls clear both notches', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(874, 402);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = GameClient(platform: 'ios')..game = GameState(levelById('corner-cafe'), playerCount: 4);
    addTearDown(client.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(874, 402), padding: EdgeInsets.fromLTRB(62, 0, 62, 21)),
          child: GameScreen(client: client, onToggleTheme: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    final arena = tester.getRect(find.byWidgetPredicate((widget) => widget is GameWidget));
    expect(arena.width, greaterThan(400));
    expect(arena.height, greaterThan(210));
    for (final label in ['Grab', 'Dash', 'Action']) {
      final bounds = tester.getRect(find.bySemanticsLabel(label));
      expect(bounds.left, greaterThanOrEqualTo(62));
      expect(bounds.right, lessThanOrEqualTo(812));
      expect(bounds.bottom, lessThanOrEqualTo(381));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('tablet touch clock stays at the right safe edge', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = GameClient(platform: 'android')
      ..game = (GameState(levelById('corner-cafe'), playerCount: 4)
        ..phase = Phase.playing
        ..score = 36
        ..combo = 2);
    addTearDown(client.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1024, 768), padding: EdgeInsets.fromLTRB(0, 24, 0, 48)),
          child: GameScreen(client: client, onToggleTheme: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    final clock = tester.getRect(find.byKey(const ValueKey('clock-hud')));
    final score = tester.getRect(find.byKey(const ValueKey('score-hud')));
    expect(clock.right, closeTo(1012, 0.1));
    expect(clock.overlaps(score), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  });

  for (final size in [const Size(402, 874), const Size(874, 402)]) {
    testWidgets('Training coach clears a full combo HUD at $size', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = GameState(levelById('training'), playerCount: 4)
        ..phase = Phase.playing
        ..score = 9999
        ..combo = 4;
      state.chefs.add(Chef(id: 'tester', slot: 0, name: 'Test', x: 2, y: 2)..held = PlateStack(count: 3, dirty: true));
      final client = GameClient(platform: 'ios')
        ..playerId = 'tester'
        ..game = state;
      addTearDown(client.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              padding: size.width > size.height
                  ? const EdgeInsets.fromLTRB(62, 0, 62, 21)
                  : const EdgeInsets.fromLTRB(0, 62, 0, 34),
            ),
            child: GameScreen(client: client, onToggleTheme: () {}),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      final coach = tester.getRect(find.byKey(const ValueKey('touch-coach')));
      final score = tester.getRect(find.byKey(const ValueKey('score-hud')));
      final clock = tester.getRect(find.byKey(const ValueKey('clock-hud')));
      expect(coach.overlaps(score), isFalse);
      expect(coach.overlaps(clock), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
