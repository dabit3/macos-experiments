import 'dart:convert';
import 'dart:io';

import '../packages/voxelhearth_core/lib/voxelhearth_core.dart' hide Platform;
import 'atlas.dart';

void main() {
  final root = File.fromUri(Platform.script).parent.parent;
  final resources = Directory(
    '${root.path}/apple/Core/Sources/HearthCore/Resources',
  )..createSync(recursive: true);
  final render = Directory('${root.path}/apple/Resources');
  File('${render.path}/atlas.rgba').writeAsBytesSync(buildAtlas().pixels);
  final tiles = List<int>.filled(256 * 2 * 4, 0);
  for (var id = 0; id < 256; id++) {
    final t = tilesFor(id);
    tiles.setRange(id * 4, id * 4 + 4, [t.top, t.side, t.bottom, 255]);
    tiles.setRange((256 + id) * 4, (256 + id) * 4 + 4, [
      id == 0 ? 0 : t.flag,
      0,
      0,
      255,
    ]);
  }
  File('${render.path}/tiles.rgba').writeAsBytesSync(tiles);
  final blocks = Registry.blocks.values
      .map(
        (b) => {
          'id': b.id,
          'name': b.name,
          'hardness': b.hardness,
          'tool': b.tool.index,
          'minTier': b.minTier.index,
          'solid': b.solid,
          'opaque': b.opaque,
          'light': b.light,
          'replaceable': b.replaceable,
          'interactive': b.interactive,
          'fluid': b.fluid,
          'decoration': b.decoration,
        },
      )
      .toList();
  final ids = {...Registry.blocks.keys, ...Registry.items.keys};
  final items = ids.map((id) {
    final item = Registry.item(id);
    return {
      'id': id,
      'name': item.name,
      'maxStack': item.maxStack,
      'tool': item.tool.index,
      'tier': item.tier.index,
      'food': item.food,
      'attack': item.attack,
      'fuelTicks': item.fuelTicks,
      'tile': id <= 33 ? tilesFor(id).side : itemTile(id),
    };
  }).toList();
  final recipes = Recipes.all
      .map(
        (r) => {
          'name': r.name,
          'result': r.result.toJson(),
          'width': r.width,
          'height': r.height,
          'pattern': r.pattern,
          'shapeless': r.shapeless,
          'gridNeeded': r.gridNeeded,
        },
      )
      .toList();
  File('${resources.path}/registry.json').writeAsStringSync(
    jsonEncode({'blocks': blocks, 'items': items, 'recipes': recipes}),
  );
  final fixtures = <Map<String, Object?>>[];
  for (final seed in [0, 1, 424242, -1234, 2147483647]) {
    for (final coords in [
      [0, 0],
      [-3, 2],
      [10, -17],
      [50, 50],
    ]) {
      final chunk = WorldGen(seed).generate(coords[0], coords[1]);
      var hash = 2166136261;
      for (final b in chunk.blocks) {
        hash = mul32(hash ^ b, 16777619);
      }
      fixtures.add({
        'seed': seed,
        'x': coords[0],
        'z': coords[1],
        'hash': hash,
      });
    }
  }
  File('${resources.path}/terrain-fixtures.json')
      .writeAsStringSync(jsonEncode(fixtures));
  final world = World(-1234);
  final edits = [
    [-17, 60, -1, 18],
    [31, 60, 17, 24],
    [-16, 61, 32, 2],
  ];
  for (final edit in edits) {
    world.set(edit[0], edit[1], edit[2], edit[3]);
  }
  final chat = [
    ['Ash', 'Hello 🌲'],
    ['Élan', 'VoxelHearth'],
    ['', ''],
  ];
  final hash = Fnv32();
  for (final line in chat) {
    hash.addString(line[0]);
    hash.addString(line[1]);
  }
  final region = [-17, 60, -1, -16, 61, 0];
  File('${resources.path}/state-fixture.json').writeAsStringSync(
    jsonEncode({
      'seed': world.seed,
      'edits': edits,
      'world': world.editsHash(),
      'chat': chat,
      'chatHash': hash.hex,
      'region': region,
      'regionHash': world.regionHash(
        region[0],
        region[1],
        region[2],
        region[3],
        region[4],
        region[5],
      ),
    }),
  );
  print(
    'Exported original atlas, tile map, registry, recipes and 20 Dart terrain parity fixtures.',
  );
}
