import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:brickfolk_server/brickfolk_server.dart';
import 'package:brickfolk_shared/brickfolk_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('port', abbr: 'p', defaultsTo: '8080')
    ..addOption('host', defaultsTo: '0.0.0.0')
    ..addOption(
      'db',
      defaultsTo: 'brickfolk.sqlite',
      help: 'SQLite file. Use :memory: for a throwaway database.',
    )
    ..addOption(
      'seed',
      defaultsTo: '0',
      help: 'Seed for room seeds and codes. 0 = random.',
    )
    ..addOption(
      'web-root',
      help: 'Optional directory of static files to serve at /.',
    )
    ..addFlag(
      'test-mode',
      help: 'Enables /test endpoints, test.report and a fixed clock.',
    )
    ..addOption(
      'match-length-scale',
      defaultsTo: '1',
      help: 'Multiplies match timers (test harnesses on slow emulators).',
    )
    ..addOption(
      'results-ms',
      defaultsTo: '${Room.defaultResultsMs}',
      help: 'How long rooms show results before the next lobby.',
    )
    ..addFlag(
      'fixed-clock',
      help: 'Deterministic clock (implied by --test-mode).',
    )
    ..addFlag('quiet', abbr: 'q')
    ..addFlag('help', abbr: 'h', negatable: false);
  final opts = parser.parse(args);
  if (opts.flag('help')) {
    stdout.writeln('Brickfolk server\n${parser.usage}');
    return;
  }
  final quiet = opts.flag('quiet');
  void log(String line) {
    if (!quiet) stdout.writeln('[${DateTime.now().toIso8601String()}] $line');
  }

  final testMode = opts.flag('test-mode');
  final seed = int.parse(opts.option('seed')!);
  final clock = (testMode || opts.flag('fixed-clock'))
      ? FixedClock()
      : RealClock();
  final store = Store(opts.option('db')!);
  final hub = Hub(
    store: store,
    clock: clock,
    seed: seed,
    testMode: testMode,
    matchLengthScale: double.parse(opts.option('match-length-scale')!),
    resultsMs: int.parse(opts.option('results-ms')!),
    log: log,
  );

  final router = Router()
    ..get(
      '/health',
      (Request _) => Response.ok(
        jsonEncode({'ok': true, 'protocolVersion': protocolVersion}),
        headers: _json,
      ),
    )
    ..get(
      '/ws',
      webSocketHandler((WebSocketChannel channel, _) {
        late Session session;
        session = hub.connect(
          (text) => channel.sink.add(text),
          () => channel.sink.close(),
        );
        channel.stream.listen(
          (data) {
            if (data is String) hub.handle(session, data);
          },
          onDone: () => hub.disconnect(session),
          onError: (_) => hub.disconnect(session),
        );
      }),
    );

  if (testMode) {
    router
      ..get(
        '/test/state',
        (Request _) => Response.ok(jsonEncode(hub.snapshot()), headers: _json),
      )
      ..post('/test/control', (Request req) async {
        final body = (jsonDecode(await req.readAsString()) as Map)
            .cast<String, Object?>();
        hub.testControl(body['room'] as String?, body..remove('room'));
        return Response.ok('{"ok":true}', headers: _json);
      });
  }

  Handler handler = router.call;
  final webRoot = opts.option('web-root');
  if (webRoot != null) {
    final static = createStaticHandler(webRoot, defaultDocument: 'index.html');
    handler = Cascade().add(router.call).add(static).handler;
  }
  final pipeline = Pipeline().addMiddleware(_cors).addHandler(handler);

  final server = await shelf_io.serve(
    pipeline,
    opts.option('host')!,
    int.parse(opts.option('port')!),
  );
  log(
    'Brickfolk server listening on ws://${server.address.host}:${server.port}/ws '
    '(protocol v$protocolVersion, ${testMode ? 'TEST MODE, fixed clock' : 'live'}, seed $seed)',
  );

  final ticker = Timer.periodic(
    Duration(microseconds: (1000000 / ticksPerSecond).round()),
    (_) => hub.tick(),
  );

  Future<void> shutdown(ProcessSignal sig) async {
    log('shutting down ($sig)');
    ticker.cancel();
    await server.close(force: true);
    store.close();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen(shutdown);
  ProcessSignal.sigterm.watch().listen(shutdown);
}

const _json = {'content-type': 'application/json'};

Middleware get _cors =>
    (inner) => (req) async {
      if (req.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }
      final res = await inner(req);
      return res.change(headers: _corsHeaders);
    };

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'content-type',
};
