part of 'video_errors.dart';

class VideoErrorHandler extends ErrorHandler<VideoErrorCodes> {
  const VideoErrorHandler({super.errorCodes = const VideoErrorCodes()});

  @override
  Map<String, Failure Function(ApiError)> get errorCodeToFailure => {
    errorCodes.streamForbidden: (error) => VideoFailure(
      code: error.code,
      message: LocaleKeys.app_errors_network_forbidden.tr(),
      stackTrace: error.stackTrace,
      dioException: error.dioException,
    ),
    errorCodes.rateLimited: (error) => VideoFailure(
      code: error.code,
      message: LocaleKeys.app_errors_network_rate_limited.tr(),
      stackTrace: error.stackTrace,
      dioException: error.dioException,
    ),
  };

  @override
  Failure? handleDomainException(Object error, StackTrace? stackTrace) =>
      switch (error) {
        VideoException exception => VideoFailure(
          code: exception.code,
          message: exception.reason ?? _messageFor(exception),
          needsSignIn: exception.needsSignIn,
          stackTrace: stackTrace,
        ),
        _ => null,
      };

  String _messageFor(VideoException exception) {
    final key = switch (exception.code) {
      'not_youtube_url' => LocaleKeys.app_errors_video_not_youtube_url,
      'player_config' => LocaleKeys.app_errors_video_player_config,
      'unplayable' => LocaleKeys.app_errors_video_unplayable,
      'streams_unavailable' => LocaleKeys.app_errors_video_streams_unavailable,
      'player_parse' => LocaleKeys.app_errors_video_player_parse,
      'challenge' => LocaleKeys.app_errors_video_challenge,
      'quality_unavailable' => LocaleKeys.app_errors_video_quality_unavailable,
      'unknown_quality' => LocaleKeys.app_errors_video_unknown_quality,
      'mux' => LocaleKeys.app_errors_video_mux,
      'stream_interrupted' => LocaleKeys.app_errors_video_stream_interrupted,
      'disk_write' => LocaleKeys.app_errors_video_disk_write,
      '403' => LocaleKeys.app_errors_network_forbidden,
      '429' => LocaleKeys.app_errors_network_rate_limited,
      'http_status' => LocaleKeys.app_errors_network_http_status,
      'no_connection' => LocaleKeys.app_errors_network_no_connection,
      'connection_timeout' => LocaleKeys.app_errors_network_timeout,
      'web_view_runtime' => LocaleKeys.app_errors_video_web_view_runtime,
      'js_engine' => LocaleKeys.app_errors_video_js_engine,
      'destination_unavailable' =>
        LocaleKeys.app_errors_video_destination_unavailable,
      'canceled' => LocaleKeys.app_errors_network_canceled,
      'ytdlp_not_found' => LocaleKeys.app_errors_video_ytdlp_not_found,
      'ytdlp_failed' => LocaleKeys.app_errors_video_ytdlp_failed,
      'bot_check' => LocaleKeys.app_errors_video_bot_check,
      'age_restricted' => LocaleKeys.app_errors_video_age_restricted,
      'members_only' => LocaleKeys.app_errors_video_members_only,
      'private_video' => LocaleKeys.app_errors_video_private_video,
      'video_unavailable' => LocaleKeys.app_errors_video_video_unavailable,
      _ => LocaleKeys.app_errors_unknown,
    };

    return key.tr(namedArgs: {'error': exception.code, ...exception.args});
  }
}
