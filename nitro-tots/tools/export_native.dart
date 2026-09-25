import 'dart:convert';
import 'dart:io';

import '../packages/nitro_core/lib/nitro_core.dart';

Map<String, double> point(V2 p) => {'x': p.x, 'y': p.y};

void main() {
  final catalog = {
    'characters': [
      for (final c in characters)
        {
          'id': c.id,
          'name': c.name,
          'tagline': c.tagline,
          'weight': c.weight.name,
          'color': c.primaryColor,
          'speed': c.speedBonus,
          'accel': c.accelBonus,
          'handling': c.handlingBonus,
          'mass': c.massBonus,
        },
    ],
    'karts': [
      for (final k in karts)
        {
          'id': k.id,
          'name': k.name,
          'speed': k.speed,
          'accel': k.accel,
          'handling': k.handling,
          'mass': k.weight,
          'color': k.bodyColor,
        },
    ],
    'cups': [
      for (final c in cups)
        {'id': c.id, 'name': c.name, 'trackIds': c.trackIds, 'color': c.color},
    ],
    'tracks': [
      for (final d in allTrackDefs)
        (() {
          final t = trackById(d.id);
          return {
            'id': d.id,
            'name': d.name,
            'location': d.location,
            'description': d.description,
            'isArena': d.isArena,
            'grassMargin': d.grassMargin,
            'length': t.length,
            'boundsMin': point(t.boundsMin),
            'boundsMax': point(t.boundsMax),
            'theme': {
              'ground': d.theme.ground,
              'groundAlt': d.theme.groundAlt,
              'road': d.theme.road,
              'roadEdge': d.theme.roadEdge,
              'curbA': d.theme.curbA,
              'curbB': d.theme.curbB,
              'shortcut': d.theme.shortcut,
              'accent': d.theme.accent,
              'sky': d.theme.sky,
            },
            'samples': [
              for (final s in t.samples)
                {
                  'pos': point(s.pos),
                  'tangent': point(s.tangent),
                  'width': s.width,
                  's': s.s,
                },
            ],
            'startGrid': [for (final p in t.startGrid) point(p)],
            'boostPads': [
              for (final p in t.boostPads)
                {
                  'pos': point(p.pos),
                  'angle': p.angle,
                  'length': p.length,
                  'width': p.width,
                },
            ],
            'jumps': [
              for (final p in t.jumps)
                {
                  'pos': point(p.pos),
                  'angle': p.angle,
                  'length': p.length,
                  'width': p.width,
                },
            ],
            'hazards': [
              for (final p in t.hazards)
                {
                  'kind': p.kind.name,
                  'pos': point(p.pos),
                  'angle': p.angle,
                  'range': p.range,
                },
            ],
            'itemBoxes': [for (final p in t.itemBoxes) point(p.pos)],
            'shortcuts': [
              for (final p in d.shortcuts)
                {
                  'name': p.name,
                  'polygon': [for (final v in p.polygon) point(v)],
                },
            ],
          };
        })(),
    ],
  };
  File('apple/Core/Sources/NitroCore/Resources/catalog.json')
      .writeAsStringSync(jsonEncode(catalog));
  final fixtures = <Map<String, dynamic>>[];
  for (final d in allTrackDefs) {
    final racers = [
      for (var i = 0; i < 8; i++)
        Racer(
          slot: i,
          playerId: '',
          name: characters[i].name,
          characterId: characters[i].id,
          kartId: karts[i % karts.length].id,
          isBot: true,
          platform: 'bot',
        ),
    ];
    final sim = RaceSim(
      track: trackById(d.id),
      racers: racers,
      seed: 4242,
      laps: 1,
      mode: d.isArena ? GameMode.battle : GameMode.race,
      battleSeconds: 30,
    );
    final bots = [for (var i = 0; i < 8; i++) BotDriver(slot: i, seed: 4242)];
    final snapshots = <Map<String, dynamic>>[];
    while (sim.phase != RacePhase.finished && sim.tick < 12000) {
      sim.step({}, (s, r) => bots[r.slot].drive(s, r));
      if ([120, 300, 600].contains(sim.tick))
        snapshots.add(snapshotToWire(sim));
    }
    fixtures.add({
      'trackId': d.id,
      'snapshots': snapshots,
      'tick': sim.tick,
      'results': [for (final r in sim.results ?? <RaceResult>[]) r.toJson()],
    });
  }
  File('apple/Core/Tests/NitroCoreTests/fixtures.json')
      .writeAsStringSync(jsonEncode(fixtures));
}
