import 'package:easy_localization/easy_localization.dart';

import '../../failure/failure.dart';
import '../../localization/lang/locale_keys.g.dart';
import '../api/api_errors.dart';
import '../app_error_handler/error_codes.dart';
import '../error_handler/error_handler.dart';

part 'video_error_handler.dart';

final class VideoErrorCodes extends ErrorCodes {
  final String notYouTubeUrl;
  final String playerConfig;
  final String unplayable;
  final String streamsUnavailable;
  final String playerParse;
  final String challenge;
  final String qualityUnavailable;
  final String unknownQuality;
  final String mux;
  final String streamInterrupted;
  final String streamForbidden;
  final String rateLimited;
  final String webViewRuntime;
  final String jsEngine;

  const VideoErrorCodes({
    super.otherError,
    this.notYouTubeUrl = 'not_youtube_url',
    this.playerConfig = 'player_config',
    this.unplayable = 'unplayable',
    this.streamsUnavailable = 'streams_unavailable',
    this.playerParse = 'player_parse',
    this.challenge = 'challenge',
    this.qualityUnavailable = 'quality_unavailable',
    this.unknownQuality = 'unknown_quality',
    this.mux = 'mux',
    this.streamInterrupted = 'stream_interrupted',
    this.streamForbidden = '403',
    this.rateLimited = '429',
    this.webViewRuntime = 'web_view_runtime',
    this.jsEngine = 'js_engine',
  });
}

/// Исключение предметной области «видео»: бросается источниками данных
/// и сервисами, превращается в [VideoFailure] обработчиком [VideoErrorHandler]
final class VideoException implements Exception {
  final String code;

  /// Подстановки для текста ошибки
  final Map<String, String> args;

  /// Готовый текст причины, например из ответа YouTube
  final String? reason;

  /// Войти в аккаунт YouTube (или обновить вход) — скорее всего, поможет
  final bool needsSignIn;

  const VideoException(
    this.code, {
    this.args = const {},
    this.reason,
    this.needsSignIn = false,
  });

  @override
  String toString() => 'VideoException($code, $args, $reason)';
}

final class VideoFailure extends Failure {
  /// Войти в аккаунт YouTube (или обновить вход) — скорее всего, поможет
  final bool needsSignIn;

  const VideoFailure({
    super.code,
    super.message,
    super.details,
    super.stackTrace,
    super.dioException,
    this.needsSignIn = false,
  });

  @override
  List<Object?> get props => [...super.props, needsSignIn];

  @override
  VideoFailure fromException(
    Object error, {
    StackTrace? stackTrace,
    String? message,
  }) => VideoFailure(message: message ?? '$error', stackTrace: stackTrace);

  @override
  VideoFailure fromOtherFailure(Failure other) => VideoFailure(
    code: other.code,
    message: other.message,
    details: other.details,
    stackTrace: other.stackTrace,
    dioException: other.dioException,
  );
}
