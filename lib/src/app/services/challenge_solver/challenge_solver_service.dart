import 'dart:convert';

import '../../errors/errors.dart';
import '../js_engine/js_engine_service.dart';

typedef ChallengeSolutions = ({Map<String, String> n, Map<String, String> sig});

/// Solves YouTube `n` and `sig` challenges with functions from the player's own JavaScript
abstract interface class ChallengeSolverService {
  /// `{challenge: solution}` maps for the requested challenges
  Future<ChallengeSolutions> solve({
    required String playerId,
    required Future<String> Function() playerJs,
    Set<String> n,
    Set<String> sig,
  });
}

/// The player is parsed by the yt-dlp/ejs scripts (assets/ejs): they find both
/// functions via meriyah and call them. The scripts are loaded into the engine once,
/// each player is parsed once and kept in the engine already parsed
class ChallengeSolverServiceImpl implements ChallengeSolverService {
  final JsEngineService _jsEngineService;

  /// Reads a solver script (`yt.solver.lib.min.js`, `yt.solver.core.min.js`)
  final Future<String> Function(String name) _loadScript;

  Future<void>? _loaded;
  final _preparedPlayers = <String>{};

  ChallengeSolverServiceImpl({
    required this._jsEngineService,
    required this._loadScript,
  });

  @override
  Future<ChallengeSolutions> solve({
    required String playerId,
    required Future<String> Function() playerJs,
    Set<String> n = const {},
    Set<String> sig = const {},
  }) async {
    if (n.isEmpty && sig.isEmpty) {
      return (n: const <String, String>{}, sig: const <String, String>{});
    }

    const errorCodes = VideoErrorCodes();

    final requests = [
      if (n.isNotEmpty) {'type': 'n', 'challenges': n.toList()},
      if (sig.isNotEmpty) {'type': 'sig', 'challenges': sig.toList()},
    ];
    final id = jsonEncode(playerId);
    Map<String, dynamic> output;

    /// The engine may lose its state (the window was recreated): then the scripts
    /// and the player are loaded again
    for (var attempt = 1; ; attempt++) {
      await (_loaded ??= _loadScripts().catchError((Object error) {
        _loaded = null;

        throw error;
      }));

      final prepared = _preparedPlayers.contains(playerId);
      final input = prepared
          ? '{type: "preprocessed", preprocessed_player: globalThis.__ytPlayers[$id], requests: ${jsonEncode(requests)}}'
          : jsonEncode({
              'type': 'player',
              'player': await playerJs(),
              'requests': requests,
              'output_preprocessed': true,
            });

      output =
          jsonDecode(
                await _jsEngineService.evaluate('''
(() => {
  if (typeof jsc === "undefined") return JSON.stringify({type: "reload"});
  if ($prepared && !globalThis.__ytPlayers?.[$id]) return JSON.stringify({type: "reload"});
  const output = jsc($input);
  if (output.preprocessed_player) {
    (globalThis.__ytPlayers ??= {})[$id] = output.preprocessed_player;
    delete output.preprocessed_player;
  }
  return JSON.stringify(output);
})()'''),
              )
              as Map<String, dynamic>;

      if (output['type'] != 'reload' || attempt == 2) {
        break;
      }

      _loaded = null;
      _preparedPlayers.clear();
    }

    if (output['type'] != 'result') {
      _preparedPlayers.remove(playerId);

      throw VideoException(
        errorCodes.playerParse,
        args: {'error': '${output['error']}'},
      );
    }

    _preparedPlayers.add(playerId);

    final solutions = (n: <String, String>{}, sig: <String, String>{});
    final responses = output['responses'] as List;

    for (var index = 0; index < requests.length; index++) {
      final response = responses[index] as Map<String, dynamic>;
      final type = requests[index]['type'] as String;

      if (response['type'] != 'result') {
        throw VideoException(
          errorCodes.challenge,
          args: {'type': type, 'error': '${response['error']}'},
        );
      }

      final target = type == 'n' ? solutions.n : solutions.sig;

      (response['data'] as Map).forEach(
        (challenge, solution) => target['$challenge'] = '$solution',
      );
    }

    return solutions;
  }

  Future<void> _loadScripts() async {
    final lib = await _loadScript('yt.solver.lib.min.js');
    final core = await _loadScript('yt.solver.core.min.js');

    /// Both scripts declare their API via top-level `var`:
    /// after loading these are global variables of the engine
    await _jsEngineService.evaluate(
      '$lib\n;Object.assign(globalThis, lib);\n$core\n;typeof jsc',
    );
  }
}
