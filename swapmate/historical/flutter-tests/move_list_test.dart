import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swapmate/src/theme/theme.dart';
import 'package:swapmate/src/widgets/move_list.dart';
import 'package:swapmate_core/swapmate_core.dart';

void main() {
  testWidgets('narrow move lists keep capture and drop notation on one line', (
    tester,
  ) async {
    final moves = [
      MatchMove(
        seq: 0,
        board: BoardId.a,
        color: PieceColor.white,
        number: 3,
        move: Move.parse('d1d4'),
        san: 'Qxd4',
        clockMs: 180000,
      ),
      MatchMove(
        seq: 1,
        board: BoardId.b,
        color: PieceColor.black,
        number: 1,
        move: Move.parse('P@e6'),
        san: 'P@e6',
        clockMs: 180000,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 230,
              height: 340,
              child: MoveList(moves: moves),
            ),
          ),
        ),
      ),
    );
    for (final san in ['Qxd4', 'P@e6']) {
      final text = tester.renderObject<RenderParagraph>(find.text(san));
      expect(
        text.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: san.length),
        ),
        hasLength(1),
      );
    }
    expect(tester.takeException(), isNull);
  });
}
