import 'dart:convert';
import 'dart:io';

import '../../core/lib/panic_pantry_core.dart';

void main() {
  final destination = File.fromUri(
    Platform.script.resolve('../Sources/PantryKit/Resources/levels.json'),
  );
  destination.parent.createSync(recursive: true);
  destination.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(kLevels.map((level) => level.toJson()).toList())}\n',
  );
}
