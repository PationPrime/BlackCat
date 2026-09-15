import 'package:dio/dio.dart';

import '../../api/api.dart';
import '../../constants/constants.dart';
import '../../dto/dto.dart';
import '../../errors/errors.dart';
import '../../session/session_store.dart';
import 'local_player_data_source.dart';

/// Requests made by the YouTube embedded web player
abstract interface class RemoteYouTubeDataSource {
  /// Embedded player page settings
  Future<EmbedConfigDto> getEmbedConfig(String videoId);

  /// Player JavaScript (from the cache if it was downloaded before)
  Future<String> getPlayerJs(String playerId);

  /// `/youtubei/v1/player` on behalf of the embedded player.
  /// Throws [VideoException] if the video cannot be played
  Future<PlayerResponseDto> getPlayer(
    String videoId,
    EmbedConfigDto config, {
    int? signatureTimestamp,
  });
}

final class RemoteYouTubeDataSourceImpl implements RemoteYouTubeDataSource {
  static const _embedPath = '${YouTubeConstants.origin}/embed';
  static const _playerJsPath = '${YouTubeConstants.origin}/s/player';
  static const _playerApiPath = '${YouTubeConstants.origin}/youtubei/v1/player';

  final ApiProvider _apiProvider;
  final SessionStore _sessionStore;
  final LocalPlayerDataSource _localPlayerDataSource;

  /// Players already read: no need to parse 3 MB from disk on every request
  final _players = <String, String>{};

  RemoteYouTubeDataSourceImpl({
    required this._apiProvider,
    required this._sessionStore,
    required this._localPlayerDataSource,
  });

  Dio get _dio => _apiProvider.youtube.dio;

  @override
  Future<EmbedConfigDto> getEmbedConfig(String videoId) async {
    final cookie = _sessionStore.cookieHeader;
    final response = await _dio.get<String>(
      '$_embedPath/$videoId',
      queryParameters: {'html5': '1'},
      options: Options(
        responseType: ResponseType.plain,
        headers: {
          'Referer': YouTubeConstants.embedUrl,
          'Cookie': ?cookie,
        },
      ),
    );

    await _sessionStore.update(response.headers['set-cookie']);

    final config = EmbedConfigDto.fromHtml(response.data ?? '');

    if (config == null) {
      throw VideoException(const VideoErrorCodes().playerConfig);
    }

    return config;
  }

  @override
  Future<String> getPlayerJs(String playerId) async {
    final cached =
        _players[playerId] ??
        await _localPlayerDataSource.readPlayerJs(playerId);

    if (cached != null) {
      return _players[playerId] = cached;
    }

    final response = await _dio.get<String>(
      '$_playerJsPath/$playerId/player_ias.vflset/en_US/base.js',
      options: Options(responseType: ResponseType.plain),
    );
    final code = response.data ?? '';

    await _localPlayerDataSource.writePlayerJs(playerId, code);

    return _players[playerId] = code;
  }

  @override
  Future<PlayerResponseDto> getPlayer(
    String videoId,
    EmbedConfigDto config, {
    int? signatureTimestamp,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _playerApiPath,
      queryParameters: {'prettyPrint': 'false'},
      data: {
        'context': config.context,
        'videoId': videoId,
        'playbackContext': {
          'contentPlaybackContext': {
            'html5Preference': 'HTML5_PREF_WANTS',
            'signatureTimestamp': ?signatureTimestamp,
            'encryptedHostFlags': ?config.encryptedHostFlags,
          },
        },
        'contentCheckOk': true,
        'racyCheckOk': true,
      },
      options: Options(
        contentType: Headers.jsonContentType,
        headers: {
          'Origin': YouTubeConstants.origin,
          'X-YouTube-Client-Name': config.clientName,
          'X-YouTube-Client-Version': config.clientVersion,
          'X-Goog-Visitor-Id': ?config.visitorData,
          'X-Goog-PageId': ?config.delegatedSessionId,
          ..._sessionStore.authHeaders(
            userSessionId: config.userSessionId,
            sessionIndex: config.sessionIndex,
            loggedIn: config.loggedIn,
          ),
        },
      ),
    );

    await _sessionStore.update(response.headers['set-cookie']);

    final player = PlayerResponseDto.fromJson(response.data ?? const {});

    if (!player.isPlayable) {
      final reason = player.reason;

      throw VideoException(
        const VideoErrorCodes().unplayable,
        args: {'status': '${player.status}'},
        reason: reason == null || reason.isEmpty ? null : reason,
        needsSignIn: player.requiresSignIn,
      );
    }

    return player;
  }

  /// Player version: signatureTimestamp from its code
  static int? signatureTimestampOf(String playerJs) => int.tryParse(
    RegExp(
          r'(?:signatureTimestamp|sts)\s*:\s*(\d{5})',
        ).firstMatch(playerJs)?.group(1) ??
        '',
  );
}
