import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:lastfort_core/lastfort_core.dart';

import 'client.dart';

const _botNames = <String>[
  'Ashfall',
  'Brindle',
  'Cobalt',
  'Dusk',
  'Ember',
  'Flint',
  'Gale',
  'Hollow',
  'Ivory',
  'Juniper',
  'Kestrel',
  'Lumen',
  'Marrow',
  'Nettle',
  'Onyx',
  'Pike',
  'Quill',
  'Rook',
  'Sable',
  'Tarn',
  'Umber',
  'Vesper',
  'Wren',
  'Yarrow',
];

/// A lobby that becomes a match. Owns the authoritative [Sim], the fixed-step
/// tick loop, the bots and the per-viewer snapshot caches.
class Room {
  Room({
    required this.code,
    required this.mode,
    required this.fast,
    required this.seed,
    required this.hostToken,
    required this.onEmpty,
    this.onReport,
  }) : rules = fast ? const Rules.fast() : const Rules();

  final String code;
  SquadMode mode;
  final bool fast;
  final int seed;
  final Rules rules;
  String hostToken;
  final void Function(Room) onEmpty;

  /// Receives client-side match reports (`testControl` op `report`) so the
  /// cross-platform test can compare what each client actually displayed.
  final void Function(Room, Map<String, Object?>)? onReport;

  final Map<String, Client> members = {}; // token -> client
  final Map<String, ViewerCache> caches = {};
  final Map<String, bool> ready = {};
  final Map<String, bool> autopilot = {};
  final Map<String, BotBrain> _pilots = {};
  final List<BotBrain> bots = [];
  Sim? sim;
  Timer? _timer;
  int _behind = 0;
  final Stopwatch _clock = Stopwatch();
  bool paused = false;
  int? countdownEndsMs;
  Timer? _countdown;
  Timer? _cleanup;
  int _nextId = 1;
  final Map<String, int> playerIds = {};
  int tickBudgetPerFrame = 5;

  bool get inLobby => sim == null || sim!.phase == MatchPhase.lobby;
  bool get ended => sim?.phase == MatchPhase.ended;
  int get humanCount => members.length;
  bool get isFull => members.length >= rules.maxPlayers;

  int idFor(String token) => playerIds.putIfAbsent(token, () => _nextId++);

  void join(Client c) {
    members[c.token] = c;
    c.room = this;
    c.pendingInputs.clear();
    caches[c.token] = ViewerCache();
    idFor(c.token);
    _cleanup?.cancel();
    _cleanup = null;
    broadcastRoomState();
  }

  /// Returns true when the client was mid-match and should be resumed.
  bool rejoin(Client c) {
    final s = sim;
    members[c.token] = c;
    c.room = this;
    caches[c.token] = ViewerCache();
    if (s == null || s.phase == MatchPhase.lobby) {
      broadcastRoomState();
      return false;
    }
    final p = s.players[idFor(c.token)];
    if (p != null) {
      p.connected = true;
      s.events.add(SimEvent('reconnected', {'tick': s.tick, 'p': p.id}));
    }
    return true;
  }

  void leave(Client c, {bool graceful = true}) {
    if (members[c.token] != c) return;
    members.remove(c.token);
    final s = sim;
    if (s != null &&
        s.phase != MatchPhase.lobby &&
        s.phase != MatchPhase.ended) {
      final p = s.players[idFor(c.token)];
      if (p != null) {
        if (graceful) {
          c.room = null;
          p.connected = false;
          _pilots.remove(c.token);
          s.events.add(SimEvent('left', {'tick': s.tick, 'p': p.id}));
          _removeFromMatch(p);
        } else {
          // Keep the client bound to the room so a reconnect can resume.
          p.connected = false;
          p.disconnectedAtTick = s.tick;
          s.events.add(SimEvent('disconnected', {'tick': s.tick, 'p': p.id}));
        }
      }
    } else {
      c.room = null;
      caches.remove(c.token);
      ready.remove(c.token);
      playerIds.remove(c.token);
      _ensureHost();
      broadcastRoomState();
    }
    if (members.isEmpty) _scheduleCleanup();
  }

  /// Hands the host role to a connected member when the host has gone, so a
  /// host who dropped mid-match never leaves the room without a host.
  void _ensureHost() {
    if (!members.containsKey(hostToken) && members.isNotEmpty) {
      hostToken = members.keys.first;
    }
  }

  void _removeFromMatch(Player p) {
    final s = sim!;
    if (!p.eliminated) {
      s.eliminate(p, byId: 0, cause: 'left');
    }
  }

  void _scheduleCleanup() {
    _cleanup?.cancel();
    _cleanup = Timer(Duration(seconds: inLobby ? 5 : 30), () {
      if (members.isEmpty) dispose();
    });
  }

  void dispose() {
    _timer?.cancel();
    _countdown?.cancel();
    _cleanup?.cancel();
    onEmpty(this);
  }

  // ------------------------------------------------------------- lobby

  Map<String, Object?> roomStateJson() {
    final list = <Map<String, Object?>>[];
    for (final e in members.entries) {
      list.add({
        'id': idFor(e.key),
        'name': e.value.name,
        'platform': e.value.platform,
        'ready': ready[e.key] ?? false,
        'host': e.key == hostToken,
        'ld': e.value.loadout.toJson(),
        'team': _teamFor(e.key),
      });
    }
    list.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    return {
      'code': code,
      'mode': mode.name,
      'fast': fast,
      'seed': seed,
      'maxPlayers': rules.maxPlayers,
      'players': list,
      'phase': sim?.phase.name ?? 'lobby',
      'countdownMs': countdownEndsMs == null
          ? null
          : math.max(
              0, countdownEndsMs! - DateTime.now().millisecondsSinceEpoch),
    };
  }

  int _teamFor(String token) {
    final s = sim;
    if (s != null) return s.players[idFor(token)]?.team ?? 0;
    final ordered = members.keys.toList()
      ..sort((a, b) => idFor(a).compareTo(idFor(b)));
    return ordered.indexOf(token) ~/ mode.size;
  }

  void broadcastRoomState() {
    final state = roomStateJson();
    for (final c in members.values) {
      c.send({'t': Protocol.roomState, 'you': idFor(c.token), ...state});
    }
  }

  void broadcast(Map<String, Object?> msg) {
    for (final c in members.values) {
      c.send(msg);
    }
  }

  void setMode(SquadMode m) {
    if (!inLobby) return;
    mode = m;
    broadcastRoomState();
  }

  void setReady(Client c, bool r) {
    ready[c.token] = r;
    broadcastRoomState();
  }

  /// Host-only: start a countdown and then the match. [fill] is the total
  /// player count including humans; the rest are bots.
  /// Clears the finished match so the same room can play again.
  void resetToLobby() {
    if (!ended) return;
    _timer?.cancel();
    _timer = null;
    sim = null;
    bots.clear();
    _pilots.clear();
    _heldEvents.clear();
    ready.clear();
    paused = false;
    _matchesPlayed++;
    for (final k in caches.keys.toList()) {
      caches[k] = ViewerCache();
    }
    broadcastRoomState();
  }

  int _matchesPlayed = 0;

  void scheduleStart({int? fill, int countdownMs = 3000}) {
    if (ended) resetToLobby();
    if (!inLobby || _countdown != null) return;
    countdownEndsMs = DateTime.now().millisecondsSinceEpoch + countdownMs;
    broadcastRoomState();
    _countdown = Timer(Duration(milliseconds: countdownMs), () {
      _countdown = null;
      countdownEndsMs = null;
      startMatch(fill: fill);
    });
  }

  void startMatch({int? fill}) {
    if (!inLobby) return;
    final s = Sim(rules: rules, seed: seed + _matchesPlayed * 7919, mode: mode);
    sim = s;
    final humans = members.keys.toList()
      ..sort((a, b) => idFor(a).compareTo(idFor(b)));
    var team = 0;
    var inTeam = 0;
    for (final token in humans) {
      final c = members[token]!;
      s.addPlayer(
        id: idFor(token),
        name: c.name,
        team: team,
        isBot: false,
        loadout: c.loadout,
        platform: c.platform,
      );
      inTeam++;
      if (inTeam >= mode.size) {
        team++;
        inTeam = 0;
      }
    }
    // Bots first complete the last (partial) human squad, then form their own.
    final target =
        (fill ?? rules.maxPlayers).clamp(humans.length, rules.maxPlayers);
    final botRng = Rng(seed ^ 0xB07);
    final names = List<String>.from(_botNames);
    var botTeam = team;
    for (var i = humans.length; i < target; i++) {
      final id = _nextId++;
      final name = names.isEmpty
          ? 'Bot$id'
          : names.removeAt(botRng.nextInt(names.length));
      final outfits = cosmeticsFor(CosmeticSlot.outfit);
      final gliders = cosmeticsFor(CosmeticSlot.glider);
      final p = s.addPlayer(
        id: id,
        name: name,
        team: botTeam,
        isBot: true,
        loadout: Loadout(
          outfit: outfits[botRng.nextInt(outfits.length)].id,
          glider: gliders[botRng.nextInt(gliders.length)].id,
        ),
        platform: 'bot',
      );
      bots.add(BotBrain(p, seed ^ (id * 7919), s));
      inTeam++;
      if (inTeam >= mode.size) {
        botTeam++;
        inTeam = 0;
      }
    }
    s.start();
    for (final token in humans) {
      caches[token] = ViewerCache();
      // Frames queued for an earlier match carry stale sequence numbers.
      members[token]!.pendingInputs.clear();
      if (autopilot[token] == true) _enablePilot(token);
    }
    broadcast({
      't': Protocol.matchStart,
      'code': code,
      'seed': s.seed,
      'mode': mode.name,
      'rules': rules.toJson(),
      'tick': s.tick,
      'players': [
        for (final p in s.players.values) p.toSnapshotJson(full: false)
      ],
    });
    for (final token in humans) {
      members[token]!.send({'t': 'you', 'id': idFor(token)});
    }
    _clock
      ..reset()
      ..start();
    _ticksDone = 0;
    _behind = 0;
    _timer = Timer.periodic(
        Duration(microseconds: (1e6 / rules.tickRate).round()),
        (_) => _frame());
  }

  Map<String, Object?> matchStartJsonFor(String token) => {
        't': Protocol.matchStart,
        'code': code,
        'seed': sim!.seed,
        'mode': mode.name,
        'rules': rules.toJson(),
        'tick': sim!.tick,
        'resume': true,
        'players': [
          for (final p in sim!.players.values) p.toSnapshotJson(full: false)
        ],
      };

  // ------------------------------------------------------------- ticking

  int _ticksDone = 0;

  void _frame() {
    final s = sim;
    if (s == null) return;
    if (paused) {
      _clock
        ..reset()
        ..start();
      _ticksDone = 0;
      return;
    }
    final targetTicks =
        (_clock.elapsedMicroseconds * rules.tickRate / 1e6).floor();
    var budget = tickBudgetPerFrame;
    while (_ticksDone < targetTicks && budget-- > 0) {
      stepOnce();
      _ticksDone++;
    }
    if (_ticksDone < targetTicks) {
      _behind++;
      // Give up catching up if the host is starved; resync the clock.
      _ticksDone = targetTicks;
    }
  }

  /// Advances exactly one tick: applies queued human inputs, bot inputs,
  /// steps the sim, then fans out snapshots.
  final List<SimEvent> _heldEvents = [];

  /// Advances the match by one tick. With [emit] false the snapshot fanout is
  /// skipped and events are held until the next emitting tick (used by the
  /// test-control `step` op to fast-forward cheaply).
  void stepOnce({bool emit = true}) {
    final s = sim!;
    if (s.phase == MatchPhase.ended) return;
    for (final c in members.values) {
      final p = s.players[idFor(c.token)];
      if (p == null) continue;
      final pilot = _pilots[c.token];
      if (pilot != null) {
        s.applyInput(p, pilot.think());
        c.pendingInputs.clear();
        continue;
      }
      if (c.pendingInputs.isEmpty) continue;
      // Apply every queued frame so actions are never dropped; movement
      // from intermediate frames is folded into the final one.
      final frames = c.pendingInputs.toList();
      c.pendingInputs.clear();
      for (var i = 0; i < frames.length; i++) {
        final f = frames[i];
        if (i < frames.length - 1) {
          s.applyInput(
              p, InputFrame(seq: f.seq, actions: f.actions, aim: f.aim));
        } else {
          s.applyInput(p, f);
        }
      }
    }
    for (final b in bots) {
      if (b.player.eliminated) continue;
      s.applyInput(b.player, b.think());
    }
    _timeoutDisconnected(s);
    s.step();
    _heldEvents.addAll(s.drainEvents());
    if (!emit && s.phase != MatchPhase.ended) return;
    final events = _heldEvents.toList();
    _heldEvents.clear();
    for (final c in members.values) {
      final p = s.players[idFor(c.token)];
      if (p == null) continue;
      final cache = caches[c.token] ??= ViewerCache();
      final snap = s.snapshotFor(p, cache, events: events);
      c.send({'t': Protocol.snapshot, ...snap});
    }
    if (s.phase == MatchPhase.ended) {
      _timer?.cancel();
      _timer = null;
      final summary = s.summary!;
      broadcast({'t': Protocol.matchEnd, 'summary': summary});
      if (!members.containsKey(hostToken)) {
        _ensureHost();
        broadcastRoomState();
      }
      if (members.isEmpty) _scheduleCleanup();
    }
  }

  void _timeoutDisconnected(Sim s) {
    final grace = (rules.reconnectGrace * rules.tickRate).round();
    for (final p in s.players.values) {
      if (p.isBot || p.connected || p.eliminated) continue;
      if (members.values.any((c) => idFor(c.token) == p.id)) continue;
      if (s.tick - p.disconnectedAtTick > grace) {
        s.eliminate(p, byId: 0, cause: 'timeout');
      }
    }
  }

  // ------------------------------------------------------------- input

  void queueInput(Client c, InputFrame f) {
    if (c.pendingInputs.length > 8) c.pendingInputs.removeAt(0);
    c.pendingInputs.add(f);
  }

  // ------------------------------------------------------------- test control

  void _enablePilot(String token) {
    final s = sim;
    if (s == null) return;
    final p = s.players[idFor(token)];
    if (p == null) return;
    final spot = _pilotLanding ??= BotBrain.quietLanding(
      s,
      [for (final b in bots) (x: b.landX, y: b.landY)],
    );
    final jitter = Rng(seed ^ p.id);
    _pilots[token] = BotBrain(
      p,
      seed ^ (p.id * 104729),
      s,
      landX: spot.x + jitter.range(-6, 6),
      landY: spot.y + jitter.range(-6, 6),
    );
  }

  ({double x, double y})? _pilotLanding;
  Map<String, BotBrain> get pilotsDebug => _pilots;

  Map<String, Object?> testControl(Client c, Map<String, Object?> m) {
    final op = m['op'] as String? ?? '';
    switch (op) {
      case 'autopilot':
        final on = m['on'] != false;
        autopilot[c.token] = on;
        if (on) {
          _enablePilot(c.token);
        } else {
          _pilots.remove(c.token);
        }
        return {'op': op, 'on': on};
      case 'pause':
        paused = true;
        return {'op': op, 'tick': sim?.tick};
      case 'resume':
        paused = false;
        return {'op': op, 'tick': sim?.tick};
      case 'step':
        final n = (m['n'] as num? ?? 1).toInt().clamp(1, 20000);
        final every = (m['every'] as num? ?? 1).toInt().clamp(1, 100);
        if (sim == null) return {'op': op, 'error': 'no match'};
        for (var i = 0; i < n && !ended; i++) {
          stepOnce(emit: i % every == every - 1 || i == n - 1);
        }
        return {'op': op, 'tick': sim!.tick};
      case 'summary':
        return {'op': op, 'summary': sim?.summary};
      case 'state':
        return {
          'op': op,
          'tick': sim?.tick,
          'phase': sim?.phase.name,
          'players': sim?.players.length,
          'behind': _behind,
          'me': sim?.players[idFor(c.token)]?.toSnapshotJson(full: true),
        };
      case 'start':
        scheduleStart(
          fill: (m['fill'] as num?)?.toInt(),
          countdownMs: (m['countdownMs'] as num? ?? 0).toInt(),
        );
        return {'op': op};
      case 'report':
        final report = <String, Object?>{
          'platform': m['platform'] ?? c.platform,
          'name': c.name,
          'playerId': idFor(c.token),
          'digest': m['digest'],
          'summary': m['summary'],
          'snapshots': m['snapshots'],
          'test': m['test'],
          'screen': m['screen'],
          'receivedAt': DateTime.now().toUtc().toIso8601String(),
        };
        onReport?.call(this, report);
        return {'op': op, 'stored': true};
      default:
        return {'op': op, 'error': 'unknown op'};
    }
  }

  String debugLine() => jsonEncode({
        'code': code,
        'humans': members.length,
        'tick': sim?.tick,
        'phase': sim?.phase.name
      });
}
