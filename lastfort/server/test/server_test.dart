import 'dart:async';
import 'dart:convert';

import 'package:lastfort_core/lastfort_core.dart';
import 'package:lastfort_server/lastfort_server.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _Peer {
  _Peer(this.channel, this.platform);
  final WebSocketChannel channel;
  final String platform;
  final List<Map<String, Object?>> inbox = [];
  final StreamController<Map<String, Object?>> _ctrl =
      StreamController.broadcast();
  String? token;
  int? id;
  Map<String, Object?>? summary;
  int snapshots = 0;

  void listen() {
    channel.stream.listen((dynamic raw) {
      final m = (jsonDecode(raw as String) as Map).cast<String, Object?>();
      if (m['t'] == Protocol.welcome) token = m['token'] as String;
      if (m['t'] == 'you') id = (m['id'] as num).toInt();
      if (m['t'] == Protocol.snapshot) snapshots++;
      if (m['t'] == Protocol.matchEnd) {
        summary = m['summary'] as Map<String, Object?>;
      }
      inbox.add(m);
      _ctrl.add(m);
    });
  }

  void send(Map<String, Object?> m) => channel.sink.add(jsonEncode(m));

  final Map<String, int> _cursors = {};

  /// Marks every already-received message of [type] as consumed.
  void drain(String type) => _cursors[type] = inbox.length;

  /// Returns the next message of [type] that has not been consumed by an
  /// earlier [waitFor] call.
  Future<Map<String, Object?>> waitFor(String type,
      {Duration timeout = const Duration(seconds: 10)}) async {
    while (true) {
      for (var i = _cursors[type] ?? 0; i < inbox.length; i++) {
        if (inbox[i]['t'] == type) {
          _cursors[type] = i + 1;
          return inbox[i];
        }
      }
      final seen = inbox.length;
      await _ctrl.stream.first.timeout(timeout);
      if (inbox.length == seen) continue;
    }
  }
}

void main() {
  late LastfortServer server;

  setUp(() async {
    server = LastfortServer(verbose: false, seed: 1);
    await server.start(host: '127.0.0.1', port: 0);
  });

  tearDown(() => server.stop());

  Future<_Peer> connect(String platform, {String? token}) async {
    final ch =
        WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:${server.port}/ws'));
    await ch.ready;
    final p = _Peer(ch, platform)..listen();
    p.send({
      't': Protocol.hello,
      'v': Protocol.version,
      'name': platform.toUpperCase(),
      'platform': platform,
      if (token != null) 'token': token,
    });
    await p.waitFor(Protocol.welcome);
    return p;
  }

  test('rooms: create, join by code, errors, host start with bots', () async {
    final a = await connect('web');
    final b = await connect('ios');
    a.send({
      't': Protocol.createRoom,
      'mode': 'duos',
      'fast': true,
      'seed': 7,
      'code': 'TEST1'
    });
    final rs = await a.waitFor(Protocol.roomState);
    expect(rs['code'], 'TEST1');
    b.send({'t': Protocol.joinRoom, 'code': 'nope'});
    final err = await b.waitFor(Protocol.error);
    expect(err['code'], ProtocolError.roomNotFound);
    b.send({'t': Protocol.joinRoom, 'code': 'test1'});
    final rs2 = await b.waitFor(Protocol.roomState);
    expect((rs2['players'] as List<Object?>).length, 2);
    b.send({'t': Protocol.startMatch});
    final notHost = await b.waitFor(Protocol.error);
    expect(notHost['code'], ProtocolError.notHost);
    a.send({'t': Protocol.startMatch, 'fill': 6, 'countdownMs': 0});
    final ms = await a.waitFor(Protocol.matchStart);
    expect((ms['players'] as List<Object?>).length, 6);
    await b.waitFor(Protocol.matchStart);
    await a.waitFor(Protocol.snapshot);
    await b.waitFor(Protocol.snapshot);
    await a.channel.sink.close();
    await b.channel.sink.close();
  });

  test('four platforms in one squad finish a match with identical summaries',
      timeout: const Timeout(Duration(seconds: 90)), () async {
    final peers = [
      await connect('web'),
      await connect('ios'),
      await connect('android'),
      await connect('macos'),
    ];
    peers[0].send({
      't': Protocol.createRoom,
      'mode': 'squads',
      'fast': true,
      'seed': 42,
      'code': 'E2E42'
    });
    await peers[0].waitFor(Protocol.roomState);
    for (final p in peers.skip(1)) {
      p.send({'t': Protocol.joinRoom, 'code': 'E2E42'});
      await p.waitFor(Protocol.roomState);
    }
    for (final p in peers) {
      p.send({'t': Protocol.testControl, 'op': 'autopilot', 'on': true});
      await p.waitFor(Protocol.testAck);
    }
    peers[0].send({'t': Protocol.startMatch, 'fill': 16, 'countdownMs': 0});
    for (final p in peers) {
      await p.waitFor(Protocol.matchStart);
      await p.waitFor('you');
    }
    // All four humans share team 0.
    final ms = peers[0].inbox.firstWhere((m) => m['t'] == Protocol.matchStart);
    final teams = {
      for (final pj in ms['players'] as List<Object?>)
        if ((pj as Map<String, Object?>)['b'] == false) pj['t']
    };
    expect(teams, {0});

    // Fast-forward the match deterministically instead of waiting real time.
    final room = server.rooms['E2E42']!;
    room.paused = true;
    peers[0].send(
        {'t': Protocol.testControl, 'op': 'step', 'n': 20000, 'every': 5});
    await peers[0]
        .waitFor(Protocol.testAck, timeout: const Duration(seconds: 60));
    for (final p in peers) {
      await p.waitFor(Protocol.matchEnd, timeout: const Duration(seconds: 30));
    }
    final encoded = peers.map((p) => jsonEncode(p.summary)).toSet();
    expect(encoded.length, 1,
        reason: 'all clients must receive the same summary');
    final summary = peers[0].summary!;
    final players =
        (summary['players'] as List<Object?>).cast<Map<String, Object?>>();
    expect(players.length, 16);
    final humans = players.where((p) => p['bot'] == false).toList();
    expect(humans.map((p) => p['platform']).toSet(),
        {'web', 'ios', 'android', 'macos'});
    expect(humans.every((p) => (p['placement'] as int) >= 1), isTrue);
    final harvested =
        humans.fold<int>(0, (s, p) => s + (p['harvested'] as int));
    final built = humans.fold<int>(0, (s, p) => s + (p['built'] as int));
    expect(harvested, greaterThan(0));
    expect(built, greaterThan(0));
    expect(peers.every((p) => p.snapshots > 100), isTrue);
    // The summary is reachable over HTTP too, for the e2e harness.
    for (final p in peers) {
      await p.channel.sink.close();
    }
  });

  test('bots complete a partial human squad before forming their own',
      () async {
    final peers = [
      await connect('web'),
      await connect('ios'),
      await connect('macos'),
    ];
    peers[0].send({
      't': Protocol.createRoom,
      'mode': 'squads',
      'fast': true,
      'seed': 9,
      'code': 'PART3'
    });
    await peers[0].waitFor(Protocol.roomState);
    for (final p in peers.skip(1)) {
      p.send({'t': Protocol.joinRoom, 'code': 'PART3'});
      await p.waitFor(Protocol.roomState);
    }
    peers[0].send({'t': Protocol.startMatch, 'fill': 8, 'countdownMs': 0});
    final ms = await peers[0].waitFor(Protocol.matchStart);
    final players =
        (ms['players'] as List<Object?>).cast<Map<String, Object?>>();
    expect(players.length, 8);
    final byTeam = <int, List<Map<String, Object?>>>{};
    for (final p in players) {
      byTeam.putIfAbsent(p['t'] as int, () => []).add(p);
    }
    expect(byTeam.keys.toSet(), {0, 1});
    expect(byTeam[0]!.length, 4);
    expect(byTeam[0]!.where((p) => p['b'] == false).length, 3);
    expect(byTeam[0]!.where((p) => p['b'] == true).length, 1);
    expect(byTeam[1]!.every((p) => p['b'] == true), isTrue);
    for (final p in peers) {
      await p.channel.sink.close();
    }
  });

  test('reconnect resumes the same player mid-match', () async {
    final a = await connect('web');
    a.send({
      't': Protocol.createRoom,
      'mode': 'solo',
      'fast': true,
      'seed': 3,
      'code': 'RECON'
    });
    await a.waitFor(Protocol.roomState);
    a.send({'t': Protocol.startMatch, 'fill': 4, 'countdownMs': 0});
    await a.waitFor('you');
    final room = server.rooms['RECON']!;
    room.paused = true;
    a.send({'t': Protocol.testControl, 'op': 'step', 'n': 5});
    await a.waitFor(Protocol.testAck);
    final myId = a.id;
    await a.channel.sink.close();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(room.sim!.players[myId]!.connected, isFalse);

    final b = await connect('web', token: a.token);
    expect(b.token, a.token);
    final ms = await b.waitFor(Protocol.matchStart);
    expect(ms['resume'], isTrue);
    final you = await b.waitFor('you');
    expect(you['id'], myId);
    expect(room.sim!.players[myId]!.connected, isTrue);
    await b.channel.sink.close();
  });

  test('a room can play a second match after the first ends', () async {
    final a = await connect('macos');
    a.send({
      't': Protocol.createRoom,
      'mode': 'solo',
      'fast': true,
      'seed': 9,
      'code': 'AGAIN'
    });
    await a.waitFor(Protocol.roomState);
    final room = server.rooms['AGAIN']!;
    for (var round = 0; round < 2; round++) {
      a.send({'t': Protocol.startMatch, 'fill': 3, 'countdownMs': 0});
      await a.waitFor(Protocol.roomState); // countdown announcement
      final start = await a.waitFor(Protocol.matchStart);
      a.drain(Protocol.snapshot);
      expect((start['players'] as List<Object?>).length, 3);
      expect(start['seed'], room.sim!.seed);
      await a.waitFor('you');
      // The live tick loop must advance a fresh match from tick zero without
      // waiting out the ticks the previous match already consumed.
      final snap = await a.waitFor(Protocol.snapshot,
          timeout: const Duration(milliseconds: 700));
      expect((snap['tick'] as num).toInt(), lessThan(10));
      // A client restarts its input sequence for every match; frames left
      // over from the previous match must not shadow the new ones.
      a.send({
        't': Protocol.input,
        'f': {'seq': 1, 'mx': 1, 'my': 0}
      });
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(room.sim!.players[a.id!]!.lastInputSeq, 1);
      // Let the real-time loop run for a while, then fast-forward the rest.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      for (var i = 0; i < 20000 && !room.ended; i++) {
        room.stepOnce(emit: false);
      }
      expect(room.ended, isTrue);
      await a.waitFor(Protocol.matchEnd);
      // Queue a stale high-sequence frame that the finished match never
      // consumes.
      a.send({
        't': Protocol.input,
        'f': {'seq': 5000, 'mx': 0, 'my': 1}
      });
      await Future<void>.delayed(const Duration(milliseconds: 100));
      a.send({'t': 'returnToLobby'});
      await a.waitFor(Protocol.roomState);
      expect(room.inLobby, isTrue);
    }
    await a.channel.sink.close();
  });

  test('a second connection with the same token supersedes the first',
      () async {
    final a = await connect('web');
    a.send({'t': Protocol.createRoom, 'mode': 'solo', 'code': 'TWICE'});
    await a.waitFor(Protocol.roomState);

    final b = await connect('web', token: a.token);
    expect(b.token, a.token);
    final err = await a.waitFor(Protocol.error);
    expect(err['code'], ProtocolError.superseded);
    // The new socket inherits the lobby seat.
    final rs = await b.waitFor(Protocol.roomState);
    expect(rs['code'], 'TWICE');
    expect((rs['players'] as List<Object?>).length, 1);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // The stale socket closing must not remove the player from the lobby.
    expect(server.rooms['TWICE'], isNotNull);
    expect(server.rooms['TWICE']!.members.length, 1);
    await b.channel.sink.close();
  });

  test('disconnected players time out and the match still ends', () async {
    final a = await connect('android');
    a.send({
      't': Protocol.createRoom,
      'mode': 'solo',
      'fast': true,
      'seed': 5,
      'code': 'TMOUT'
    });
    await a.waitFor(Protocol.roomState);
    a.send({'t': Protocol.startMatch, 'fill': 3, 'countdownMs': 0});
    await a.waitFor('you');
    final room = server.rooms['TMOUT']!;
    room.paused = true;
    await a.channel.sink.close();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    for (var i = 0; i < 20000 && !room.ended; i++) {
      room.stepOnce();
    }
    expect(room.ended, isTrue);
    final summary = room.sim!.summary!;
    final me = (summary['players'] as List<Object?>)
        .cast<Map<String, Object?>>()
        .firstWhere((p) => p['platform'] == 'android');
    expect(me['placement'], greaterThan(1));
  });

  test('host role passes to a connected player when the host drops mid-match',
      () async {
    final a = await connect('macos');
    final b = await connect('ios');
    a.send({
      't': Protocol.createRoom,
      'mode': 'duos',
      'fast': true,
      'seed': 11,
      'code': 'HOSTX'
    });
    await a.waitFor(Protocol.roomState);
    b.send({'t': Protocol.joinRoom, 'code': 'HOSTX'});
    await b.waitFor(Protocol.roomState);
    a.send({'t': Protocol.startMatch, 'fill': 4, 'countdownMs': 0});
    await a.waitFor('you');
    await b.waitFor('you');
    final room = server.rooms['HOSTX']!;
    room.paused = true;
    await a.channel.sink.close();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    b.drain(Protocol.roomState);
    for (var i = 0; i < 20000 && !room.ended; i++) {
      room.stepOnce();
    }
    expect(room.ended, isTrue);
    await b.waitFor(Protocol.matchEnd);
    final rs = await b.waitFor(Protocol.roomState);
    final me = (rs['players'] as List<Object?>)
        .cast<Map<String, Object?>>()
        .firstWhere((p) => p['id'] == rs['you']);
    expect(me['host'], isTrue);
    b.send({'t': 'returnToLobby'});
    final lobby = await b.waitFor(Protocol.roomState);
    expect(lobby['phase'], 'lobby');
    await b.channel.sink.close();
  });
}
