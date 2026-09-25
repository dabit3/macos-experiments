import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voxelhearth/app_state.dart';
import 'package:voxelhearth/audio.dart';
import 'package:voxelhearth/game/game_controller.dart';
import 'package:voxelhearth/game/renderer.dart';
import 'package:voxelhearth/net/game_client.dart';
import 'package:voxelhearth/ui/chat_panel.dart';
import 'package:voxelhearth/ui/game_screen.dart';
import 'package:voxelhearth/ui/lobby_screen.dart';
import 'package:voxelhearth/ui/pixel.dart';
import 'package:voxelhearth/ui/touch_controls.dart';
import 'package:voxelhearth_core/voxelhearth_core.dart';

void main() {
  setUp(() => Sfx.enabled = false);

  testWidgets('joystick moves in the camera-relative direction and releases cleanly', (tester) async {
    await tester.binding.setSurfaceSize(const Size(874, 402));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final assets = (await tester.runAsync(RenderAssets.load))!;
    final client = GameClient(platform: 'ios');
    final session = RoomSession(1234)
      ..phase = Phase.playing
      ..mode = GameMode.creative
      ..spawnX = 8
      ..spawnY = 70
      ..spawnZ = 8;
    final game = GameController(client, session, assets)..flying = true;
    final frame = FrameNotifier();
    addTearDown(() {
      game.dispose();
      client.dispose();
      frame.dispose();
      assets.atlasImage.dispose();
      assets.tileMap.dispose();
      assets.dirt.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TouchControls(game: game, frame: frame),
        ),
      ),
    );
    for (final yaw in [0.0, 1.2]) {
      game.camera.yaw = yaw;
      for (final drag in [const Offset(0, -40), const Offset(0, 40), const Offset(-40, 0), const Offset(40, 0)]) {
        game.body.setPos(8, 70, 8);
        game.body.vx = game.body.vz = 0;
        final gesture = await tester.startGesture(const Offset(84, 240));
        await gesture.moveBy(drag);
        await tester.pump();
        await gesture.moveBy(drag);
        await tester.pump();
        await tester.runAsync(() async {
          game.update(0.05);
          await game.view.upload();
        });
        final forward = game.camera.forward;
        final right = game.camera.right;
        final dx = game.body.x - 8;
        final dz = game.body.z - 8;
        final alongDrag = drag.dy != 0
            ? (dx * forward[0] + dz * forward[2]) * -drag.dy.sign
            : (dx * right[0] + dz * right[2]) * drag.dx.sign;
        expect(alongDrag, greaterThan(0), reason: 'drag=$drag yaw=$yaw');
        await gesture.up();
        await tester.pump();
        expect([game.joyX, game.joyY, game.touchSprint], [0, 0, false]);
      }
    }
  });

  testWidgets('button borders and focus stay within a compact menu row', (tester) async {
    await tester.binding.setSurfaceSize(const Size(874, 402));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 350,
              child: Row(
                children: [
                  PxButton('Create World', width: 85, onPressed: () {}),
                  const SizedBox(width: 10),
                  PxButton('Player', width: 85, onPressed: () {}),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(PxButton).first), const Size(170, 40));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(PxButton).first), const Size(170, 40));
  });

  testWidgets('keyboard activates enabled buttons and skips disabled buttons', (tester) async {
    var activations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const PxButton('Unavailable'),
              PxButton('Play', primary: true, onPressed: () => activations++),
            ],
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(activations, 1);
    await tester.tap(find.text('Unavailable'));
    await tester.pumpAndSettle();
    expect(activations, 1);
  });

  testWidgets('phone lobby keeps chat focus and draft when the keyboard opens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(874, 402));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    final client = GameClient(platform: 'ios');
    final session = RoomSession(1234)
      ..youId = 'phone'
      ..hostId = 'web'
      ..roomName = 'Testing'
      ..code = 'HEARTH'
      ..chat.add(ChatEntry(1, 'Web', 'Hello from Web', false, DateTime(2026)));
    addTearDown(client.dispose);
    addTearDown(settings.dispose);

    Widget lobby(double keyboard) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(874, 402),
          padding: const EdgeInsets.fromLTRB(62, 0, 62, 21),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: LobbyScreen(client: client, session: session, settings: settings),
      ),
    );

    await tester.pumpWidget(lobby(0));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'phone draft');
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
    await tester.pumpWidget(lobby(220));
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
    expect(find.text('phone draft'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(lobby(0));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(ChatPanel)).height, greaterThanOrEqualTo(90));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
