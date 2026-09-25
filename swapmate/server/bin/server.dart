import 'dart:io';

import 'package:swapmate_server/swapmate_server.dart';

/// Usage:
///   dart run bin/server.dart [--port 8787] [--host 0.0.0.0] [--seed 42]
///                            [--bot-delay-ms 700] [--test] [--static <directory>]
///
/// Environment fallbacks: PORT, SWAPMATE_SEED, SWAPMATE_TEST=1, SWAPMATE_STATIC.
Future<void> main(List<String> args) async {
  String? opt(String name) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final env = Platform.environment;
  final port = int.parse(opt('port') ?? env['PORT'] ?? '8787');
  final host = opt('host') ?? env['HOST'] ?? '0.0.0.0';
  final seedText = opt('seed') ?? env['SWAPMATE_SEED'];
  final testMode = args.contains('--test') || env['SWAPMATE_TEST'] == '1';
  final botDelay = int.parse(
    opt('bot-delay-ms') ?? env['SWAPMATE_BOT_DELAY_MS'] ?? '700',
  );
  final staticDir = opt('static') ?? env['SWAPMATE_STATIC'];

  final server = SwapmateServer(
    ServerConfig(
      seed: seedText == null ? null : int.parse(seedText),
      botDelayMs: botDelay,
      testMode: testMode,
    ),
    staticDir: staticDir,
  );
  await server.start(host: host, port: port);
  stdout.writeln(
    'swapmate server listening on ws://$host:${server.port}/ws'
    '${testMode ? ' (test mode)' : ''}'
    '${seedText != null ? ' seed=$seedText' : ''}'
    '${staticDir != null ? ' static=$staticDir' : ''}',
  );

  ProcessSignal.sigint.watch().listen((_) async {
    await server.stop();
    exit(0);
  });
}
