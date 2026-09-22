import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:peeky_cat/src/app/services/services.dart';

/// JS engine for tests only: flutter test does not open a WebView2 window,
/// so scripts run in a persistent Node `vm` context
/// (global variables persist between calls, as in WebView)
class NodeJsEngineService implements JsEngineService {
  static const _host = r'''
const vm = require('vm');
const context = vm.createContext({ console });
let buffer = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (data) => {
  buffer += data;
  for (let i; (i = buffer.indexOf('\n')) >= 0; ) {
    const { script } = JSON.parse(buffer.slice(0, i));
    buffer = buffer.slice(i + 1);
    let reply;
    try { reply = { ok: vm.runInContext(script, context) }; } catch (e) { reply = { error: String(e && e.stack || e) }; }
    process.stdout.write(JSON.stringify(reply) + '\n');
  }
});
''';

  Process? _process;
  StreamIterator<String>? _replies;

  @override
  Future<String> evaluate(String script) async {
    if (_process == null) {
      final process = _process = await Process.start('node', ['-e', _host]);

      _replies = StreamIterator(
        process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
      );
    }

    _process!.stdin.writeln(jsonEncode({'script': script}));
    await _process!.stdin.flush();

    if (!await _replies!.moveNext()) {
      throw StateError('node exited');
    }

    final reply = jsonDecode(_replies!.current) as Map<String, dynamic>;

    if (reply.containsKey('error')) {
      throw StateError('JS error: ${reply['error']}');
    }

    final value = reply['ok'];

    return value is String ? value : jsonEncode(value);
  }

  void dispose() => _process?.kill();
}
