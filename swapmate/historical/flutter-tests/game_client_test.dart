import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:swapmate/src/net/game_client.dart';
import 'package:swapmate_core/swapmate_core.dart';

RoomState _room(RoomPhase phase, {bool ready = false}) => RoomState(
  code: 'SWAP',
  phase: phase,
  hostId: 'player',
  timeControl: TimeControl.blitz3,
  players: [
    PlayerInfo(
      id: 'player',
      name: 'Tester',
      seat: Seat.aWhite,
      ready: ready,
      isBot: false,
      connected: true,
      platform: 'test',
    ),
  ],
  spectators: const [],
  rematchVotes: const [],
);

Future<void> _publish(
  WebSocket socket,
  GameClient client,
  Map<String, Object?> message,
  bool Function() received,
) async {
  final done = Completer<void>();
  void listener() {
    if (received() && !done.isCompleted) done.complete();
  }

  client.addListener(listener);
  socket.add(jsonEncode(message));
  try {
    await done.future.timeout(const Duration(seconds: 3));
  } finally {
    client.removeListener(listener);
  }
}

void main() {
  test('room transitions discard errors from earlier screens', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final incoming = server.transform(WebSocketTransformer()).first;
    final client = GameClient(platform: 'test');
    addTearDown(client.dispose);
    final connected = client.connect(
      url: 'ws://127.0.0.1:${server.port}',
      name: 'Tester',
    );
    final socket = await incoming;
    socket.listen((_) {});
    addTearDown(socket.close);
    await connected;
    await _publish(socket, client, {
      'type': MsgType.welcome,
      'playerId': 'player',
      'resumeToken': 'synthetic-test-token',
      'serverTime': DateTime.now().millisecondsSinceEpoch,
    }, () => client.isOnline);

    Future<void> error(String code) => _publish(socket, client, {
      'type': MsgType.error,
      'code': code,
      'message': code,
    }, () => client.lastError?.code == code);
    Future<void> room(RoomState state) => _publish(
      socket,
      client,
      {'type': MsgType.roomState, 'room': state.toJson()},
      () =>
          client.room?.phase == state.phase &&
          client.me?.ready == state.players.first.ready,
    );

    await error(ErrorCode.roomNotFound);
    await room(_room(RoomPhase.lobby));
    expect(client.lastError, isNull);

    await error(ErrorCode.notReady);
    await room(_room(RoomPhase.lobby, ready: true));
    expect(client.lastError?.code, ErrorCode.notReady);
    await room(_room(RoomPhase.playing, ready: true));
    expect(client.lastError, isNull);

    await error(ErrorCode.illegalMove);
    client.leaveRoom();
    expect(client.room, isNull);
    expect(client.lastError, isNull);
  });
}
