import 'dart:convert';
import 'dart:io';

import '../../core/lib/panic_pantry_core.dart';

void main() {
  final fixtures = <Map<String, Object>>[];
  for (final level in kLevels) {
    final state = GameState(level, playerCount: 4);
    final sim = Simulation(state, seed: 1234);
    final coordinator = BotCoordinator();
    final bots = <Bot>[];
    for (var slot = 0; slot < 4; slot++) {
      final id = 'bot$slot';
      state.chefs.add(
        Chef(id: id, slot: slot, name: 'Bot $slot', x: 0, y: 0, bot: true),
      );
      bots.add(Bot(id, seed: 1234 + slot, coordinator: coordinator));
    }
    sim.startRound();
    final snapshots = <Map<String, dynamic>>[state.toSnapshot()];
    while (state.phase != Phase.finished) {
      for (final bot in bots) {
        sim.pending[bot.chefId] = bot.think(state, Rules.tickSeconds);
      }
      sim.step();
      if ([120, 850].contains(state.tick)) snapshots.add(state.toSnapshot());
      state.events.clear();
    }
    snapshots.add(state.toSnapshot());
    fixtures.add({
      'level': level.id,
      'snapshots': snapshots,
      'results': state.results(),
    });
  }
  final file = File.fromUri(
    Platform.script.resolve('../Tests/PantryKitTests/Fixtures/rounds.json'),
  );
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(fixtures)}\n',
  );
}
