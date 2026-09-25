import 'dart:io';

import 'package:lastfort_server/lastfort_server.dart';

/// Usage: dart run bin/server.dart [--port 8787] [--host 0.0.0.0]
///   [--web-root <directory>] [--fast] [--seed N] [--quiet]
Future<void> main(List<String> args) async {
  var port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8787;
  var host = '0.0.0.0';
  String? webRoot;
  var fast = false;
  var verbose = true;
  int? seed;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--port':
        port = int.parse(args[++i]);
      case '--host':
        host = args[++i];
      case '--web-root':
        webRoot = args[++i];
      case '--fast':
        fast = true;
      case '--seed':
        seed = int.parse(args[++i]);
      case '--quiet':
        verbose = false;
      default:
        stderr.writeln('unknown argument ${args[i]}');
        exit(64);
    }
  }
  final server = LastfortServer(
    webRoot: webRoot,
    verbose: verbose,
    defaultFast: fast,
    seed: seed,
  );
  await server.start(host: host, port: port);
  ProcessSignal.sigint.watch().listen((_) async {
    await server.stop();
    exit(0);
  });
}
