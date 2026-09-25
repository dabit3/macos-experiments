import 'dart:convert';
import 'dart:io';

import 'package:brickfolk_shared/brickfolk_shared.dart';

void main() {
  final course = ObbyCourse.instance;
  final arena = TagArena.instance;
  final content = {
    'catalog': catalog.map((v) => v.toJson()).toList(),
    'bodyColors': bodyColors,
    'bodyColorNames': bodyColorNames,
    'dailyRewards': DailyReward.streakRewards,
    'badges': badges.map((v) => v.toJson()).toList(),
    'places': places.map((v) => v.toJson()).toList(),
    'bricks': brickTypes.map((v) => v.toJson()).toList(),
    'upgrades': tycoonUpgrades.map((v) => v.toJson()).toList(),
    'obby': {
      'platforms': course.platforms.map((v) => v.toJson()).toList(),
      'checkpoints': course.checkpoints
          .map((v) => {'x': v.x, 'y': v.y})
          .toList(),
      'finishX': course.finishX,
    },
    'tag': {
      'width': arena.width,
      'height': arena.height,
      'walls': arena.walls.map((v) => v.toJson()).toList(),
    },
  };
  File('../apple/Sources/BrickfolkCore/Resources/content.json')
      .writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(content)}\n',
      );
}
