import 'dart:typed_data';

import '../packages/voxelhearth_core/lib/voxelhearth_core.dart';

/// Original Voxelhearth pixel-art tiles, generated procedurally so every
/// platform ships byte-identical textures without any binary assets.
class Tiles {
  static const stone = 0,
      dirt = 1,
      grassTop = 2,
      grassSide = 3,
      sand = 4,
      water = 5,
      logSide = 6,
      logTop = 7;
  static const leaves = 8,
      planks = 9,
      cobble = 10,
      coalOre = 11,
      ironOre = 12,
      goldOre = 13,
      emberOre = 14,
      bedrock = 15;
  static const torch = 16,
      benchTop = 17,
      benchSide = 18,
      kilnFront = 19,
      kilnTop = 20,
      chestSide = 21,
      chestTop = 22,
      chestFront = 23;
  static const bedTop = 24,
      bedSide = 25,
      glass = 26,
      gravel = 27,
      snow = 28,
      flower = 29,
      tallGrass = 30,
      brick = 31;
  static const stoneBrick = 32,
      lantern = 33,
      cactusSide = 34,
      cactusTop = 35,
      wool = 36,
      mossStone = 37,
      frostLogSide = 38,
      frostLogTop = 39;
  static const frostLeaves = 40,
      clay = 41,
      snowGrassSide = 42,
      kilnSide = 43,
      lanternTop = 44,
      bedBottom = 45;
  static const stick = 48,
      coal = 49,
      ironIngot = 50,
      goldIngot = 51,
      emberGem = 52,
      rawIron = 53,
      rawGold = 54;
  static const woodPick = 55, stonePick = 56, ironPick = 57, emberPick = 58;
  static const woodAxe = 59, stoneAxe = 60, ironAxe = 61;
  static const woodShovel = 63, stoneShovel = 64, ironShovel = 65;
  static const woodSword = 67, stoneSword = 68, ironSword = 69, emberSword = 70;
  static const apple = 71,
      rawChop = 72,
      cookedChop = 73,
      mossberry = 74,
      stew = 75,
      brickItem = 76,
      clayBall = 77,
      woolTuft = 78;

  static const columns = 16;
  static const rows = 5;
  static const size = 16;
  static const width = columns * size;
  static const height = rows * size;
}

/// Shader flags stored in the tile map alpha channel.
class TileFlag {
  static const solid = 0,
      cutout = 1,
      fluid = 2,
      glass = 3,
      torch = 4,
      plant = 5,
      cactus = 6,
      bed = 7,
      lantern = 8;
}

class BlockTiles {
  const BlockTiles(this.top, this.side, this.bottom, this.flag);
  final int top, side, bottom, flag;
}

BlockTiles tilesFor(int blockId) {
  switch (blockId) {
    case Ids.stone:
      return const BlockTiles(Tiles.stone, Tiles.stone, Tiles.stone, 0);
    case Ids.dirt:
      return const BlockTiles(Tiles.dirt, Tiles.dirt, Tiles.dirt, 0);
    case Ids.grass:
      return const BlockTiles(Tiles.grassTop, Tiles.grassSide, Tiles.dirt, 0);
    case Ids.sand:
      return const BlockTiles(Tiles.sand, Tiles.sand, Tiles.sand, 0);
    case Ids.water:
      return const BlockTiles(
        Tiles.water,
        Tiles.water,
        Tiles.water,
        TileFlag.fluid,
      );
    case Ids.log:
      return const BlockTiles(Tiles.logTop, Tiles.logSide, Tiles.logTop, 0);
    case Ids.leaves:
      return const BlockTiles(
        Tiles.leaves,
        Tiles.leaves,
        Tiles.leaves,
        TileFlag.cutout,
      );
    case Ids.planks:
      return const BlockTiles(Tiles.planks, Tiles.planks, Tiles.planks, 0);
    case Ids.cobble:
      return const BlockTiles(Tiles.cobble, Tiles.cobble, Tiles.cobble, 0);
    case Ids.coalOre:
      return const BlockTiles(Tiles.coalOre, Tiles.coalOre, Tiles.coalOre, 0);
    case Ids.ironOre:
      return const BlockTiles(Tiles.ironOre, Tiles.ironOre, Tiles.ironOre, 0);
    case Ids.goldOre:
      return const BlockTiles(Tiles.goldOre, Tiles.goldOre, Tiles.goldOre, 0);
    case Ids.emberOre:
      return const BlockTiles(
        Tiles.emberOre,
        Tiles.emberOre,
        Tiles.emberOre,
        0,
      );
    case Ids.bedrock:
      return const BlockTiles(Tiles.bedrock, Tiles.bedrock, Tiles.bedrock, 0);
    case Ids.torch:
      return const BlockTiles(
        Tiles.torch,
        Tiles.torch,
        Tiles.torch,
        TileFlag.torch,
      );
    case Ids.workbench:
      return const BlockTiles(Tiles.benchTop, Tiles.benchSide, Tiles.planks, 0);
    case Ids.kiln:
      return const BlockTiles(Tiles.kilnTop, Tiles.kilnFront, Tiles.kilnTop, 0);
    case Ids.chest:
      return const BlockTiles(
        Tiles.chestTop,
        Tiles.chestFront,
        Tiles.chestTop,
        0,
      );
    case Ids.bed:
      return const BlockTiles(
        Tiles.bedTop,
        Tiles.bedSide,
        Tiles.bedBottom,
        TileFlag.bed,
      );
    case Ids.glass:
      return const BlockTiles(
        Tiles.glass,
        Tiles.glass,
        Tiles.glass,
        TileFlag.glass,
      );
    case Ids.gravel:
      return const BlockTiles(Tiles.gravel, Tiles.gravel, Tiles.gravel, 0);
    case Ids.snow:
      return const BlockTiles(Tiles.snow, Tiles.snowGrassSide, Tiles.dirt, 0);
    case Ids.flower:
      return const BlockTiles(
        Tiles.flower,
        Tiles.flower,
        Tiles.flower,
        TileFlag.plant,
      );
    case Ids.tallGrass:
      return const BlockTiles(
        Tiles.tallGrass,
        Tiles.tallGrass,
        Tiles.tallGrass,
        TileFlag.plant,
      );
    case Ids.brick:
      return const BlockTiles(Tiles.brick, Tiles.brick, Tiles.brick, 0);
    case Ids.stoneBrick:
      return const BlockTiles(
        Tiles.stoneBrick,
        Tiles.stoneBrick,
        Tiles.stoneBrick,
        0,
      );
    case Ids.lantern:
      return const BlockTiles(
        Tiles.lanternTop,
        Tiles.lantern,
        Tiles.lanternTop,
        TileFlag.lantern,
      );
    case Ids.cactus:
      return const BlockTiles(
        Tiles.cactusTop,
        Tiles.cactusSide,
        Tiles.cactusTop,
        TileFlag.cactus,
      );
    case Ids.wool:
      return const BlockTiles(Tiles.wool, Tiles.wool, Tiles.wool, 0);
    case Ids.mossStone:
      return const BlockTiles(
        Tiles.mossStone,
        Tiles.mossStone,
        Tiles.mossStone,
        0,
      );
    case Ids.frostLog:
      return const BlockTiles(
        Tiles.frostLogTop,
        Tiles.frostLogSide,
        Tiles.frostLogTop,
        0,
      );
    case Ids.frostLeaves:
      return const BlockTiles(
        Tiles.frostLeaves,
        Tiles.frostLeaves,
        Tiles.frostLeaves,
        TileFlag.cutout,
      );
    case Ids.clay:
      return const BlockTiles(Tiles.clay, Tiles.clay, Tiles.clay, 0);
    default:
      return const BlockTiles(Tiles.stone, Tiles.stone, Tiles.stone, 0);
  }
}

int itemTile(int itemId) {
  switch (itemId) {
    case Ids.stick:
      return Tiles.stick;
    case Ids.coal:
      return Tiles.coal;
    case Ids.ironIngot:
      return Tiles.ironIngot;
    case Ids.goldIngot:
      return Tiles.goldIngot;
    case Ids.emberGem:
      return Tiles.emberGem;
    case Ids.rawIron:
      return Tiles.rawIron;
    case Ids.rawGold:
      return Tiles.rawGold;
    case Ids.woodPick:
      return Tiles.woodPick;
    case Ids.stonePick:
      return Tiles.stonePick;
    case Ids.ironPick:
      return Tiles.ironPick;
    case Ids.emberPick:
      return Tiles.emberPick;
    case Ids.woodAxe:
      return Tiles.woodAxe;
    case Ids.stoneAxe:
      return Tiles.stoneAxe;
    case Ids.ironAxe:
      return Tiles.ironAxe;
    case Ids.woodShovel:
      return Tiles.woodShovel;
    case Ids.stoneShovel:
      return Tiles.stoneShovel;
    case Ids.ironShovel:
      return Tiles.ironShovel;
    case Ids.woodSword:
      return Tiles.woodSword;
    case Ids.stoneSword:
      return Tiles.stoneSword;
    case Ids.ironSword:
      return Tiles.ironSword;
    case Ids.emberSword:
      return Tiles.emberSword;
    case Ids.apple:
      return Tiles.apple;
    case Ids.rawChop:
      return Tiles.rawChop;
    case Ids.cookedChop:
      return Tiles.cookedChop;
    case Ids.mossberry:
      return Tiles.mossberry;
    case Ids.heartyStew:
      return Tiles.stew;
    case Ids.brickItem:
      return Tiles.brickItem;
    case Ids.ballOfClay:
      return Tiles.clayBall;
    case Ids.woolTuft:
      return Tiles.woolTuft;
    default:
      return Tiles.stick;
  }
}

/// A tiny pixel painter over the shared RGBA buffer.
class _Px {
  _Px(this.buf, this.tile);
  final Uint8List buf;
  final int tile;
  late final Rng rng = Rng(tile * 7919 + 17);

  int _ofs(int x, int y) {
    final tx = (tile % Tiles.columns) * Tiles.size + x;
    final ty = (tile ~/ Tiles.columns) * Tiles.size + y;
    return (ty * Tiles.width + tx) * 4;
  }

  void set(int x, int y, int argb, {int a = 255}) {
    if (x < 0 || y < 0 || x >= 16 || y >= 16) return;
    final o = _ofs(x, y);
    buf[o] = (argb >> 16) & 0xff;
    buf[o + 1] = (argb >> 8) & 0xff;
    buf[o + 2] = argb & 0xff;
    buf[o + 3] = a;
  }

  int get(int x, int y) {
    final o = _ofs(x, y);
    return (buf[o] << 16) | (buf[o + 1] << 8) | buf[o + 2];
  }

  void clear() {
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 16; x++) {
        set(x, y, 0, a: 0);
      }
    }
  }

  /// Fills the tile with a colour jittered by [v] (0..1) per pixel.
  void noise(int base, double v, {int? blend, double blendChance = 0}) {
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 16; x++) {
        var c = base;
        if (blend != null && rng.nextDouble() < blendChance) c = blend;
        set(x, y, shade(c, 1 + (rng.nextDouble() * 2 - 1) * v));
      }
    }
  }

  void rect(int x0, int y0, int w, int h, int c, {double v = 0}) {
    for (var y = y0; y < y0 + h; y++) {
      for (var x = x0; x < x0 + w; x++) {
        set(x, y, v == 0 ? c : shade(c, 1 + (rng.nextDouble() * 2 - 1) * v));
      }
    }
  }

  void specks(int c, int count, {int size = 1}) {
    for (var i = 0; i < count; i++) {
      final x = rng.nextInt(16), y = rng.nextInt(16);
      for (var dy = 0; dy < size; dy++) {
        for (var dx = 0; dx < size; dx++) {
          set(x + dx, y + dy, shade(c, 0.85 + rng.nextDouble() * 0.3));
        }
      }
    }
  }

  void cells(
    int base,
    int line, {
    int cellW = 8,
    int cellH = 4,
    int offset = 4,
  }) {
    // Brick-like grid with staggered rows.
    for (var y = 0; y < 16; y++) {
      final row = y ~/ cellH;
      final shift = row.isOdd ? offset : 0;
      for (var x = 0; x < 16; x++) {
        final inLineY = y % cellH == cellH - 1;
        final inLineX = (x + shift) % cellW == cellW - 1;
        set(
          x,
          y,
          inLineY || inLineX ? line : shade(base, 0.9 + rng.nextDouble() * 0.2),
        );
      }
    }
  }
}

int shade(int argb, double f) {
  int ch(int v) => (v * f).round().clamp(0, 255);
  return (ch((argb >> 16) & 0xff) << 16) |
      (ch((argb >> 8) & 0xff) << 8) |
      ch(argb & 0xff);
}

int lerpColor(int a, int b, double t) {
  int ch(int x, int y) => (x + (y - x) * t).round().clamp(0, 255);
  return (ch((a >> 16) & 0xff, (b >> 16) & 0xff) << 16) |
      (ch((a >> 8) & 0xff, (b >> 8) & 0xff) << 8) |
      ch(a & 0xff, b & 0xff);
}

class AtlasData {
  AtlasData(this.pixels);
  final Uint8List pixels;

  /// ARGB colour of a pixel in [tile].
  int pixel(int tile, int x, int y) {
    final tx = (tile % Tiles.columns) * Tiles.size + x;
    final ty = (tile ~/ Tiles.columns) * Tiles.size + y;
    final o = (ty * Tiles.width + tx) * 4;
    return (pixels[o + 3] << 24) |
        (pixels[o] << 16) |
        (pixels[o + 1] << 8) |
        pixels[o + 2];
  }

  /// Average opaque colour of a tile (used for particles and map icons).
  int average(int tile) {
    var r = 0, g = 0, b = 0, n = 0;
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 16; x++) {
        final c = pixel(tile, x, y);
        if ((c >> 24) & 0xff < 128) continue;
        r += (c >> 16) & 0xff;
        g += (c >> 8) & 0xff;
        b += c & 0xff;
        n++;
      }
    }
    if (n == 0) return 0xff808080;
    return 0xff000000 | ((r ~/ n) << 16) | ((g ~/ n) << 8) | (b ~/ n);
  }
}

/// Builds the whole atlas.
AtlasData buildAtlas() {
  final buf = Uint8List(Tiles.width * Tiles.height * 4);
  _Px px(int t) => _Px(buf, t);

  // ---- terrain
  px(Tiles.stone).noise(0x8a8d90, 0.10, blend: 0x74777a, blendChance: 0.2);
  px(Tiles.dirt).noise(0x8a5a36, 0.12, blend: 0x6e4526, blendChance: 0.2);
  px(Tiles.grassTop).noise(0x5f9e3a, 0.12, blend: 0x4c8a2f, blendChance: 0.25);
  {
    final p = px(Tiles.grassSide);
    p.noise(0x8a5a36, 0.12, blend: 0x6e4526, blendChance: 0.2);
    for (var x = 0; x < 16; x++) {
      final depth = 2 + p.rng.nextInt(3);
      for (var y = 0; y < depth; y++) {
        p.set(x, y, shade(0x5f9e3a, 0.9 + p.rng.nextDouble() * 0.2));
      }
    }
  }
  px(Tiles.sand).noise(0xe0cf94, 0.07, blend: 0xd2bf80, blendChance: 0.2);
  {
    final p = px(Tiles.water);
    p.noise(0x2f6fb4, 0.05);
    for (var i = 0; i < 6; i++) {
      final y = p.rng.nextInt(16),
          x = p.rng.nextInt(16),
          len = 3 + p.rng.nextInt(4);
      for (var k = 0; k < len; k++) {
        p.set((x + k) % 16, y, 0x4d8dd0);
      }
    }
  }
  {
    final p = px(Tiles.logSide);
    for (var x = 0; x < 16; x++) {
      final band = (x % 4 == 0) ? 0x4a3420 : 0x6a4a2c;
      for (var y = 0; y < 16; y++) {
        p.set(x, y, shade(band, 0.9 + p.rng.nextDouble() * 0.2));
      }
    }
  }
  {
    final p = px(Tiles.logTop);
    p.noise(0x6a4a2c, 0.06);
    for (var r = 1; r < 8; r += 2) {
      for (var a = 0; a < 64; a++) {
        final x = (8 + r * _cos(a / 64)).round(),
            y = (8 + r * _sin(a / 64)).round();
        p.set(x.clamp(0, 15), y.clamp(0, 15), 0xb08a5c);
      }
    }
    p.rect(1, 1, 14, 14, 0, v: 0);
    p.noise(0xb08a5c, 0.08);
    for (var r = 2; r < 8; r += 2) {
      for (var a = 0; a < 90; a++) {
        final x = (7.5 + r * _cos(a / 90)).round(),
            y = (7.5 + r * _sin(a / 90)).round();
        p.set(x.clamp(0, 15), y.clamp(0, 15), 0x7d5a35);
      }
    }
    for (var i = 0; i < 16; i++) {
      p.set(i, 0, 0x4a3420);
      p.set(i, 15, 0x4a3420);
      p.set(0, i, 0x4a3420);
      p.set(15, i, 0x4a3420);
    }
  }
  {
    final p = px(Tiles.leaves);
    p.clear();
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 16; x++) {
        if (p.rng.nextDouble() < 0.18) continue;
        p.set(x, y, shade(0x3f8a2e, 0.75 + p.rng.nextDouble() * 0.5));
      }
    }
  }
  {
    final p = px(Tiles.planks);
    for (var y = 0; y < 16; y++) {
      final board = y ~/ 4;
      for (var x = 0; x < 16; x++) {
        var c = 0xb98a56;
        if (y % 4 == 3) c = 0x6f4d2c;
        if ((x + board * 7) % 16 == 5 && y % 4 == 1) c = 0x5a3d22;
        p.set(x, y, shade(c, 0.93 + p.rng.nextDouble() * 0.14));
      }
    }
  }
  {
    final p = px(Tiles.cobble);
    p.noise(0x7d8083, 0.12);
    for (var i = 0; i < 9; i++) {
      final x = (i % 3) * 5 + p.rng.nextInt(2),
          y = (i ~/ 3) * 5 + p.rng.nextInt(2);
      final w = 3 + p.rng.nextInt(2), h = 3 + p.rng.nextInt(2);
      p.rect(x, y, w, h, 0x969a9d, v: 0.08);
      for (var k = 0; k < w; k++) {
        p.set(x + k, y + h, 0x55585b);
      }
      for (var k = 0; k < h; k++) {
        p.set(x + w, y + k, 0x55585b);
      }
    }
  }
  void ore(int tile, int colour) {
    final p = px(tile);
    p.noise(0x8a8d90, 0.10, blend: 0x74777a, blendChance: 0.2);
    for (var i = 0; i < 6; i++) {
      final x = 1 + p.rng.nextInt(13), y = 1 + p.rng.nextInt(13);
      p.set(x, y, colour);
      p.set(x + 1, y, shade(colour, 0.85));
      p.set(x, y + 1, shade(colour, 0.75));
      if (p.rng.chance(0.5)) p.set(x + 1, y + 1, shade(colour, 1.15));
    }
  }

  ore(Tiles.coalOre, 0x1e1f22);
  ore(Tiles.ironOre, 0xd9a986);
  ore(Tiles.goldOre, 0xf2c744);
  ore(Tiles.emberOre, 0xff6a1a);
  px(Tiles.bedrock).noise(0x3a3b3f, 0.25, blend: 0x202124, blendChance: 0.3);
  px(Tiles.gravel).noise(0x8f8a84, 0.18, blend: 0x6b665f, blendChance: 0.3);
  px(Tiles.snow).noise(0xf2f6fa, 0.03);
  {
    final p = px(Tiles.snowGrassSide);
    p.noise(0x8a5a36, 0.12, blend: 0x6e4526, blendChance: 0.2);
    for (var x = 0; x < 16; x++) {
      final depth = 2 + p.rng.nextInt(2);
      for (var y = 0; y < depth; y++) {
        p.set(x, y, 0xf2f6fa);
      }
    }
  }
  px(Tiles.clay).noise(0x9aa0ad, 0.06, blend: 0x8790a3, blendChance: 0.25);
  px(Tiles.wool).noise(0xf1ece4, 0.05, blend: 0xdcd5c9, blendChance: 0.3);
  px(Tiles.brick).cells(0xa8503c, 0xd9cbb8, cellW: 8, cellH: 4, offset: 4);
  px(Tiles.stoneBrick).cells(0x86898d, 0x5a5d61, cellW: 8, cellH: 8, offset: 4);
  {
    final p = px(Tiles.mossStone);
    p.noise(0x7d8083, 0.12);
    p.specks(0x4f7f33, 30, size: 2);
  }
  {
    final p = px(Tiles.frostLogSide);
    for (var x = 0; x < 16; x++) {
      final band = (x % 4 == 0) ? 0x2c3a44 : 0x4a5d6a;
      for (var y = 0; y < 16; y++) {
        p.set(x, y, shade(band, 0.9 + p.rng.nextDouble() * 0.2));
      }
    }
    p.specks(0xe8f2f8, 6);
  }
  {
    final p = px(Tiles.frostLogTop);
    p.noise(0x9fb0ba, 0.06);
    for (var i = 0; i < 16; i++) {
      p.set(i, 0, 0x2c3a44);
      p.set(i, 15, 0x2c3a44);
      p.set(0, i, 0x2c3a44);
      p.set(15, i, 0x2c3a44);
    }
    p.rect(4, 4, 8, 8, 0x7e929e, v: 0.05);
    p.rect(7, 7, 2, 2, 0x4a5d6a);
  }
  {
    final p = px(Tiles.frostLeaves);
    p.clear();
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 16; x++) {
        if (p.rng.nextDouble() < 0.2) continue;
        final snowy = p.rng.nextDouble() < 0.25;
        p.set(
          x,
          y,
          snowy ? 0xe4eef4 : shade(0x3a6e5a, 0.75 + p.rng.nextDouble() * 0.5),
        );
      }
    }
  }
  {
    final p = px(Tiles.cactusSide);
    p.noise(0x3f8a3a, 0.08);
    for (var y = 0; y < 16; y++) {
      p.set(3, y, 0x2f6a2c);
      p.set(8, y, 0x2f6a2c);
      p.set(13, y, 0x2f6a2c);
      if (y % 4 == 1) {
        p.set(4, y, 0xe8f0c8);
        p.set(9, y, 0xe8f0c8);
      }
    }
  }
  {
    final p = px(Tiles.cactusTop);
    p.noise(0x3f8a3a, 0.08);
    p.rect(1, 1, 14, 14, 0x58a850, v: 0.06);
  }

  // ---- crafted / functional blocks
  {
    final p = px(Tiles.torch);
    p.clear();
    p.rect(6, 6, 4, 10, 0x8a6a3a, v: 0.08);
    p.rect(6, 3, 4, 3, 0xffd35a);
    p.rect(7, 2, 2, 1, 0xfff0a0);
    p.rect(6, 5, 4, 1, 0xff8a2a);
  }
  {
    final p = px(Tiles.benchTop);
    p.noise(0xb98a56, 0.08);
    for (var i = 0; i < 16; i++) {
      p.set(i, 5, 0x5a3d22);
      p.set(i, 10, 0x5a3d22);
      p.set(5, i, 0x5a3d22);
      p.set(10, i, 0x5a3d22);
    }
    for (var i = 0; i < 16; i++) {
      p.set(i, 0, 0x6f4d2c);
      p.set(i, 15, 0x6f4d2c);
      p.set(0, i, 0x6f4d2c);
      p.set(15, i, 0x6f4d2c);
    }
  }
  {
    final p = px(Tiles.benchSide);
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 16; x++) {
        p.set(
          x,
          y,
          shade(y < 3 ? 0x6f4d2c : 0xb98a56, 0.93 + p.rng.nextDouble() * 0.14),
        );
      }
    }
    p.rect(2, 5, 3, 6, 0x8a8d90);
    p.rect(3, 4, 1, 1, 0x8a8d90);
    p.rect(3, 11, 1, 3, 0x5a3d22);
    p.rect(9, 5, 5, 2, 0xd9a986);
    p.rect(10, 7, 3, 6, 0x5a3d22);
  }
  {
    final p = px(Tiles.kilnSide);
    p.cells(0x76797c, 0x4a4d50, cellW: 5, cellH: 5, offset: 2);
  }
  {
    final p = px(Tiles.kilnTop);
    p.cells(0x76797c, 0x4a4d50, cellW: 5, cellH: 5, offset: 2);
    p.rect(5, 5, 6, 6, 0x3a3b3f);
  }
  {
    final p = px(Tiles.kilnFront);
    p.cells(0x76797c, 0x4a4d50, cellW: 5, cellH: 5, offset: 2);
    p.rect(4, 7, 8, 7, 0x1b1a1a);
    p.rect(5, 10, 6, 3, 0xff7a1f, v: 0.1);
    p.rect(6, 9, 4, 1, 0xffc04a);
    p.rect(7, 8, 2, 1, 0xfff0a0);
  }
  {
    final p = px(Tiles.chestSide);
    p.noise(0xa5773f, 0.08);
    for (var i = 0; i < 16; i++) {
      p.set(i, 0, 0x5a3d22);
      p.set(i, 15, 0x5a3d22);
      p.set(0, i, 0x5a3d22);
      p.set(15, i, 0x5a3d22);
      p.set(i, 6, 0x5a3d22);
    }
  }
  {
    final p = px(Tiles.chestTop);
    p.noise(0xa5773f, 0.08);
    for (var i = 0; i < 16; i++) {
      p.set(i, 0, 0x5a3d22);
      p.set(i, 15, 0x5a3d22);
      p.set(0, i, 0x5a3d22);
      p.set(15, i, 0x5a3d22);
    }
    p.rect(3, 3, 10, 10, 0xb58a52, v: 0.06);
  }
  {
    final p = px(Tiles.chestFront);
    p.noise(0xa5773f, 0.08);
    for (var i = 0; i < 16; i++) {
      p.set(i, 0, 0x5a3d22);
      p.set(i, 15, 0x5a3d22);
      p.set(0, i, 0x5a3d22);
      p.set(15, i, 0x5a3d22);
      p.set(i, 6, 0x5a3d22);
    }
    p.rect(6, 4, 4, 5, 0x9a9da0);
    p.rect(7, 6, 2, 2, 0x3a3b3f);
  }
  {
    final p = px(Tiles.bedTop);
    p.noise(0xb83a3a, 0.06);
    p.rect(0, 0, 16, 5, 0xefe6dc, v: 0.04);
    p.rect(2, 1, 12, 3, 0xffffff, v: 0.02);
    p.rect(0, 5, 16, 1, 0x8f2a2a);
  }
  {
    final p = px(Tiles.bedSide);
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 16; x++) {
        p.set(
          x,
          y,
          y < 8
              ? shade(0xb83a3a, 0.95 + p.rng.nextDouble() * 0.1)
              : shade(0x8a6a3a, 0.95 + p.rng.nextDouble() * 0.1),
        );
      }
    }
    p.rect(0, 7, 16, 1, 0x8f2a2a);
    p.rect(2, 12, 2, 4, 0x5a3d22);
    p.rect(12, 12, 2, 4, 0x5a3d22);
  }
  px(Tiles.bedBottom).noise(0x8a6a3a, 0.08);
  {
    final p = px(Tiles.glass);
    p.clear();
    for (var i = 0; i < 16; i++) {
      p.set(i, 0, 0xdbe9f2);
      p.set(i, 15, 0xdbe9f2);
      p.set(0, i, 0xdbe9f2);
      p.set(15, i, 0xdbe9f2);
    }
    for (var i = 2; i < 8; i++) {
      p.set(i, 9 - i + 2, 0xffffff);
    }
  }
  {
    final p = px(Tiles.flower);
    p.clear();
    for (var y = 8; y < 16; y++) {
      p.set(8, y, 0x3f8a2e);
    }
    p.set(6, 11, 0x3f8a2e);
    p.set(7, 10, 0x3f8a2e);
    p.set(10, 12, 0x3f8a2e);
    p.set(9, 11, 0x3f8a2e);
    p.rect(6, 4, 5, 5, 0xf4b23a);
    p.rect(7, 3, 3, 1, 0xf4b23a);
    p.rect(7, 9, 3, 1, 0xf4b23a);
    p.rect(5, 5, 1, 3, 0xf4b23a);
    p.rect(11, 5, 1, 3, 0xf4b23a);
    p.rect(7, 5, 3, 3, 0xe8542a);
  }
  {
    final p = px(Tiles.tallGrass);
    p.clear();
    for (var i = 0; i < 7; i++) {
      final x = 1 + i * 2 + p.rng.nextInt(2);
      final h = 6 + p.rng.nextInt(8);
      final c = shade(0x5f9e3a, 0.8 + p.rng.nextDouble() * 0.4);
      for (var y = 16 - h; y < 16; y++) {
        p.set(x + ((16 - y) ~/ 6), y, c);
      }
    }
  }
  {
    final p = px(Tiles.lantern);
    p.clear();
    p.rect(4, 3, 8, 10, 0x2f2f33);
    p.rect(5, 4, 6, 8, 0xffd35a, v: 0.06);
    p.rect(6, 6, 4, 4, 0xfff4c0);
    p.rect(7, 1, 2, 2, 0x2f2f33);
    p.rect(4, 13, 8, 1, 0x2f2f33);
  }
  {
    final p = px(Tiles.lanternTop);
    p.clear();
    p.rect(4, 4, 8, 8, 0x2f2f33);
    p.rect(6, 6, 4, 4, 0xffd35a);
  }

  // ---- items
  {
    final p = px(Tiles.stick);
    p.clear();
    for (var i = 0; i < 12; i++) {
      p.set(3 + i, 13 - i, 0x8a6a3a);
      p.set(4 + i, 13 - i, 0x6a4a2c);
    }
  }
  void lump(int tile, int c) {
    final p = px(tile);
    p.clear();
    p.rect(4, 5, 8, 7, c, v: 0.12);
    p.rect(5, 4, 6, 1, c);
    p.rect(5, 12, 6, 1, shade(c, 0.7));
    p.rect(6, 6, 2, 2, shade(c, 1.35));
  }

  lump(Tiles.coal, 0x232428);
  lump(Tiles.rawIron, 0xc79a78);
  lump(Tiles.rawGold, 0xd9b23a);
  lump(Tiles.clayBall, 0x9aa0ad);
  void ingot(int tile, int c) {
    final p = px(tile);
    p.clear();
    p.rect(3, 8, 10, 4, c);
    p.rect(4, 6, 8, 2, shade(c, 1.2));
    p.rect(3, 12, 10, 1, shade(c, 0.6));
    p.rect(12, 7, 1, 5, shade(c, 0.75));
  }

  ingot(Tiles.ironIngot, 0xd6d9dc);
  ingot(Tiles.goldIngot, 0xf2c744);
  {
    final p = px(Tiles.emberGem);
    p.clear();
    for (var y = 0; y < 8; y++) {
      final w = y < 4 ? y * 2 + 1 : (7 - y) * 2 + 1;
      final x0 = 8 - w ~/ 2 - (y < 4 ? 0 : 0);
      p.rect(x0, 4 + y, w, 1, y < 4 ? 0xff8a3a : 0xd94d12);
    }
    p.rect(7, 6, 2, 2, 0xffe2a8);
  }
  void tool(int tile, String kind, int head, int handle) {
    final p = px(tile);
    p.clear();
    // diagonal handle bottom-left to top-right
    for (var i = 0; i < 9; i++) {
      p.set(3 + i, 13 - i, handle);
      p.set(4 + i, 13 - i, shade(handle, 0.75));
    }
    switch (kind) {
      case 'pick':
        p.rect(7, 2, 8, 2, head);
        p.rect(6, 4, 2, 3, head);
        p.rect(13, 4, 2, 3, head);
        p.rect(9, 4, 4, 1, shade(head, 0.8));
      case 'axe':
        p.rect(9, 2, 5, 5, head);
        p.rect(8, 3, 1, 4, head);
        p.rect(10, 7, 3, 1, shade(head, 0.8));
        p.rect(13, 3, 1, 3, shade(head, 1.2));
      case 'shovel':
        p.rect(10, 2, 4, 5, head);
        p.rect(11, 1, 2, 1, head);
        p.rect(11, 5, 2, 2, shade(head, 0.8));
      case 'sword':
        for (var i = 0; i < 9; i++) {
          p.set(6 + i, 10 - i, head);
          p.set(7 + i, 10 - i, shade(head, 1.15));
        }
        p.rect(4, 9, 4, 2, 0x5a3d22);
        p.rect(5, 8, 1, 4, 0x5a3d22);
    }
  }

  const woodHead = 0xb98a56,
      stoneHead = 0x8a8d90,
      ironHead = 0xe1e4e8,
      emberHead = 0xff7a1f,
      handleC = 0x8a6a3a;
  tool(Tiles.woodPick, 'pick', woodHead, handleC);
  tool(Tiles.stonePick, 'pick', stoneHead, handleC);
  tool(Tiles.ironPick, 'pick', ironHead, handleC);
  tool(Tiles.emberPick, 'pick', emberHead, 0x3a3b3f);
  tool(Tiles.woodAxe, 'axe', woodHead, handleC);
  tool(Tiles.stoneAxe, 'axe', stoneHead, handleC);
  tool(Tiles.ironAxe, 'axe', ironHead, handleC);
  tool(Tiles.woodShovel, 'shovel', woodHead, handleC);
  tool(Tiles.stoneShovel, 'shovel', stoneHead, handleC);
  tool(Tiles.ironShovel, 'shovel', ironHead, handleC);
  tool(Tiles.woodSword, 'sword', woodHead, handleC);
  tool(Tiles.stoneSword, 'sword', stoneHead, handleC);
  tool(Tiles.ironSword, 'sword', ironHead, handleC);
  tool(Tiles.emberSword, 'sword', emberHead, 0x3a3b3f);
  {
    final p = px(Tiles.apple);
    p.clear();
    p.rect(4, 6, 8, 7, 0xd93a2f, v: 0.05);
    p.rect(5, 5, 6, 1, 0xd93a2f);
    p.rect(5, 13, 6, 1, 0xa82a22);
    p.rect(5, 6, 2, 3, 0xff7a70);
    p.rect(8, 2, 1, 3, 0x5a3d22);
    p.rect(9, 3, 3, 1, 0x3f8a2e);
  }
  {
    final p = px(Tiles.rawChop);
    p.clear();
    p.rect(4, 5, 8, 8, 0xe5788a, v: 0.06);
    p.rect(5, 4, 6, 1, 0xe5788a);
    p.rect(5, 13, 6, 1, 0xc95a6c);
    p.rect(6, 6, 2, 3, 0xf6c2cc);
    p.rect(3, 8, 1, 3, 0xf1e6dc);
  }
  {
    final p = px(Tiles.cookedChop);
    p.clear();
    p.rect(4, 5, 8, 8, 0xa2603a, v: 0.06);
    p.rect(5, 4, 6, 1, 0xa2603a);
    p.rect(5, 13, 6, 1, 0x7c4526);
    p.rect(6, 6, 2, 3, 0xd08a5c);
    p.rect(3, 8, 1, 3, 0xf1e6dc);
  }
  {
    final p = px(Tiles.mossberry);
    p.clear();
    p.rect(4, 7, 4, 4, 0x5b3fae);
    p.rect(8, 5, 4, 4, 0x5b3fae);
    p.rect(6, 10, 4, 4, 0x4a2f96);
    p.set(5, 8, 0xa78be8);
    p.set(9, 6, 0xa78be8);
    p.rect(9, 2, 1, 3, 0x3f8a2e);
  }
  {
    final p = px(Tiles.stew);
    p.clear();
    p.rect(2, 7, 12, 6, 0x8a6a3a, v: 0.06);
    p.rect(3, 13, 10, 1, 0x5a3d22);
    p.rect(3, 6, 10, 2, 0xc9622a, v: 0.08);
    p.rect(5, 6, 2, 1, 0xf4b23a);
    p.rect(9, 6, 2, 1, 0x3f8a2e);
  }
  {
    final p = px(Tiles.brickItem);
    p.clear();
    p.rect(3, 6, 10, 5, 0xa8503c, v: 0.06);
    p.rect(3, 11, 10, 1, 0x7a3428);
    p.rect(4, 6, 8, 1, 0xc46a52);
  }
  {
    final p = px(Tiles.woolTuft);
    p.clear();
    p.rect(4, 5, 8, 7, 0xf1ece4, v: 0.05);
    p.rect(5, 4, 6, 1, 0xf1ece4);
    p.rect(5, 12, 6, 1, 0xd5cec2);
    p.rect(6, 6, 2, 2, 0xffffff);
  }
  // Premultiply so translucent texels stay well-formed on every backend.
  for (var o = 0; o < buf.length; o += 4) {
    final a = buf[o + 3];
    if (a == 255) continue;
    buf[o] = buf[o] * a ~/ 255;
    buf[o + 1] = buf[o + 1] * a ~/ 255;
    buf[o + 2] = buf[o + 2] * a ~/ 255;
  }
  return AtlasData(buf);
}

double _cos(double t) => _trig(t, 0.25);
double _sin(double t) => _trig(t, 0.0);
double _trig(double t, double phase) {
  // cheap sine via polynomial on [0,1) turns
  var x = (t + phase) % 1.0;
  x = x * 2 - 1; // -1..1
  final y = 4 * x * (1 - x.abs());
  return y;
}
