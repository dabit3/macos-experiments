import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../packages/swapmate_core/lib/swapmate_core.dart';

void main(List<String> args) {
  final positions = <Position>[
    Position.initial(),
    for (final fen in [
      'k7/7P/8/8/8/8/7r/K7[] w - - 0 1',
      'k7/7Q~/8/8/8/8/7r/K7[] b - - 0 1',
      'k7/8/8/8/8/8/8/K7[Pp] w - - 0 1',
      '6rk/6pp/8/8/8/8/8/K7[N] w - - 0 1',
      'k7/8/8/8/8/8/8/K7[Qq] w - - 0 1',
      'r3k2r/8/8/3pP3/8/8/8/R3K2R[] w KQkq d6 0 1',
      'r3k2r/8/8/8/3Pp3/8/8/R3K2R[] b KQkq d3 0 1',
      'k7/2Q5/1K6/8/8/8/8/8[] b - - 0 1',
      'k7/8/8/8/8/8/1r6/K7[] w - - 0 1',
      'k7/8/8/8/1b6/8/8/R3K2R[] w KQ - 0 1',
      'k7/8/8/4KPpr/8/8/8/8[] w - g6 0 1',
    ])
      Position.fromFen(fen),
  ];
  final random = Random(42);
  for (var match = 0; match < 4; match++) {
    final game = BughouseMatch(
      timeControl: const TimeControl(initialMs: 300000, incrementMs: 2000),
    )..start(0);
    for (var ply = 0; ply < 120 && !game.isOver; ply++) {
      final board = BoardId.values[random.nextInt(2)];
      final seat = game.seatToMove(board);
      final moves = game.legalMoves(seat);
      if (moves.isEmpty) break;
      if (ply % 4 == 0) positions.add(game.position(board));
      game.play(seat, moves[random.nextInt(moves.length)], ply * 100);
    }
  }
  final fixtures = [
    for (final position in positions)
      {
        'fen': position.fen,
        'inCheck': position.inCheck(),
        'legal': position.legalMoves().map((m) => m.uci).toList()..sort(),
      },
  ];
  final output = File(args.single);
  output.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(fixtures)}\n',
  );
  stdout.writeln('${fixtures.length} authoritative position fixtures written');
}
