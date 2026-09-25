import 'dart:convert';
import 'dart:io';

import '../../core/lib/lastfort_core.dart';

void main() {
  final root = File(Platform.script.toFilePath()).parent.parent;
  final resources = Directory('${root.path}/Resources');
  final fixtures = Directory('${root.path}/Tests/LastfortKitTests/Fixtures')
    ..createSync(recursive: true);
  void write(String path, Object data) =>
      File(path).writeAsStringSync('${jsonEncode(data)}\n');
  write('${resources.path}/catalogue.json', {
    'cosmetics': [
      for (final c in cosmetics)
        {
          'id': c.id,
          'slot': c.slot.name,
          'name': c.name,
          'rarity': c.rarity.name,
          'primary': c.primary,
          'secondary': c.secondary,
          'accent': c.accent,
          'description': c.description,
          'shape': c.shape,
        },
    ],
    'tiers': [
      for (final t in passTiers)
        {'tier': t.tier, 'xpRequired': t.xpRequired, 'rewardId': t.rewardId},
    ],
  });
  for (final seed in [0, 4242, 2147483647]) {
    const rules = Rules.fast();
    final world = World.generate(rules, seed);
    write('${fixtures.path}/world-$seed.json', {
      'seed': seed,
      'rules': rules.toJson(),
      'terrain': world.terrain.toList(),
      'pois': [for (final p in world.pois) p.toJson()],
      'nodes': [for (final n in world.nodes) n.toJson()],
      'chests': [for (final c in world.chests) c.toJson()],
      'structures': [for (final s in world.buildings) s.toJson()],
    });
  }
  final sim = Sim(
    rules: const Rules.fast(),
    seed: 4242,
    mode: SquadMode.squads,
  );
  final player = sim.addPlayer(
    id: 1,
    name: 'Native',
    team: 0,
    isBot: false,
    loadout: const Loadout(),
    platform: 'macos',
  );
  sim.addPlayer(
    id: 2,
    name: 'Other',
    team: 1,
    isBot: true,
    loadout: const Loadout(),
  );
  sim.start();
  write('${fixtures.path}/match-start.json', {
    't': 'matchStart',
    'code': 'NATIVE',
    'seed': sim.seed,
    'mode': sim.mode.name,
    'rules': sim.rules.toJson(),
    'tick': sim.tick,
    'players': [
      for (final p in sim.players.values) p.toSnapshotJson(full: false),
    ],
  });
  write('${fixtures.path}/snapshot.json', {
    't': 'snapshot',
    ...sim.snapshotFor(player, ViewerCache(), events: sim.drainEvents()),
  });
  sim.eliminate(sim.players[2]!, byId: 1, cause: 'weapon');
  for (var i = 0; i < 20000 && sim.summary == null; i++) {
    sim.step();
  }
  if (sim.summary == null) throw StateError('Fixture match did not finish');
  write('${fixtures.path}/match-end.json', {
    't': 'matchEnd',
    'summary': sim.summary,
  });
  print('Exported catalogue and authoritative Dart fixtures to ${root.path}');
}
