import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swapmate/src/net/game_client.dart';
import 'package:swapmate/src/screens/game_screen.dart';
import 'package:swapmate/src/screens/home_screen.dart';
import 'package:swapmate/src/screens/lobby_screen.dart';
import 'package:swapmate/src/screens/results_screen.dart';
import 'package:swapmate/src/theme/theme.dart';
import 'package:swapmate_core/swapmate_core.dart';

GameClient _fixture(RoomPhase phase) {
  final client = GameClient(platform: 'web')
    ..playerId = 'aw'
    ..status = ConnectionStatus.online;
  client.room = RoomState(
    code: 'SWAP',
    phase: phase,
    hostId: 'aw',
    timeControl: TimeControl.blitz3,
    players: [
      for (final seat in Seat.values)
        PlayerInfo(
          id: seat.id,
          name: switch (seat) {
            Seat.aWhite => 'Moonwalker',
            Seat.aBlack => 'Captain Checkmate',
            Seat.bWhite => 'Knight Rider',
            Seat.bBlack => 'Pocket Rocket',
          },
          seat: seat,
          ready: true,
          isBot: false,
          connected: true,
          platform: ['web', 'ios', 'android', 'macos'][seat.index],
        ),
    ],
    spectators: const [],
    rematchVotes: const [],
  );
  var position = Position.initial();
  for (final color in PieceColor.values) {
    for (final type in PieceType.values.where((t) => t != PieceType.king)) {
      position = position.addToReserve(color, type);
    }
  }
  client.game = GameState(
    gameId: 'SWAP-1',
    boards: {
      for (final board in BoardId.values)
        board: BoardSnapshot(
          id: board,
          fen: position.fen,
          whiteMs: 167000,
          blackMs: 156000,
          running: phase == RoomPhase.playing ? PieceColor.white : null,
          lastMove: null,
          inCheck: false,
        ),
    },
    moves: const [],
    result: phase == RoomPhase.finished
        ? const MatchResult(
            winner: Team.one,
            reason: ResultReason.checkmate,
            board: BoardId.a,
            loser: Seat.aBlack,
          )
        : null,
    serverTime: DateTime.now().millisecondsSinceEpoch,
    premove: null,
    drawOffers: const [],
    bpgn: '[Result "1-0"]\n1-0',
  );
  return client;
}

void main() {
  setUpAll(() async {
    for (final (family, asset) in [
      ('BarlowCondensed', 'BarlowCondensed-ExtraBold'),
      ('Inter', 'Inter-Regular'),
    ]) {
      final loader = FontLoader(family)
        ..addFont(rootBundle.load('assets/fonts/$asset.ttf'));
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(800, 600),
    const Size(1180, 800),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'all screens fit $size ${brightness.name} with full reserves',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          for (final screen in ['home', 'lobby', 'game', 'results']) {
            final client = _fixture(
              screen == 'results' ? RoomPhase.finished : RoomPhase.playing,
            );
            final key = GlobalKey();
            final widget = switch (screen) {
              'home' => HomeScreen(
                client: client,
                initialName: 'Moonwalker',
                initialServer: 'ws://localhost:8787/ws',
                onConnect: (_, _) async {},
                onToggleTheme: () {},
              ),
              'lobby' => LobbyScreen(client: client, onToggleTheme: () {}),
              'game' => GameScreen(client: client, onToggleTheme: () {}),
              _ => ResultsScreen(client: client, onToggleTheme: () {}),
            };
            await tester.pumpWidget(
              MaterialApp(
                theme: buildTheme(brightness),
                home: RepaintBoundary(key: key, child: widget),
              ),
            );
            await tester.pump(const Duration(seconds: 1));
            expect(tester.takeException(), isNull, reason: screen);
            final output = Platform.environment['SWAPMATE_RENDER_DIR'];
            if (output != null) {
              final boundary =
                  key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              await tester.runAsync(() async {
                final image = await boundary.toImage();
                final data = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                image.dispose();
                await File(
                  '$output/$screen-${size.width.toInt()}-${brightness.name}.png',
                ).writeAsBytes(data!.buffer.asUint8List());
              });
            }
            await tester.pumpWidget(const SizedBox.shrink());
            client.dispose();
          }
        },
      );
    }
  }
}
