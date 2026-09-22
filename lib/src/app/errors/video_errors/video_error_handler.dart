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
      'disk_full' when exception.args.isEmpty =>
        LocaleKeys.app_errors_video_disk_full_unknown_size,
      'disk_full' => LocaleKeys.app_errors_video_disk_full,
      'unsupported_url' => LocaleKeys.app_errors_video_unsupported_url,
      'not_rutube_url' => LocaleKeys.app_errors_video_not_rutube_url,
      'rutube_unavailable' => LocaleKeys.app_errors_video_rutube_unavailable,
      'rutube_live' => LocaleKeys.app_errors_video_rutube_live,
      'rutube_http_status' => LocaleKeys.app_errors_video_rutube_http_status,
      'rutube_no_connection' =>
        LocaleKeys.app_errors_video_rutube_no_connection,
      'rutube_interrupted' => LocaleKeys.app_errors_video_rutube_interrupted,
      'not_tiktok_url' => LocaleKeys.app_errors_video_not_tiktok_url,
      'tiktok_unavailable' => LocaleKeys.app_errors_video_tiktok_unavailable,
      'tiktok_photo' => LocaleKeys.app_errors_video_tiktok_photo,
      'tiktok_http_status' => LocaleKeys.app_errors_video_tiktok_http_status,
      'tiktok_no_connection' =>
        LocaleKeys.app_errors_video_tiktok_no_connection,
      'tiktok_interrupted' => LocaleKeys.app_errors_video_tiktok_interrupted,
      'not_instagram_url' => LocaleKeys.app_errors_video_not_instagram_url,
      'instagram_unavailable' =>
        LocaleKeys.app_errors_video_instagram_unavailable,
      'instagram_photo' => LocaleKeys.app_errors_video_instagram_photo,
      'instagram_rate_limited' =>
        LocaleKeys.app_errors_video_instagram_rate_limited,
      'instagram_http_status' =>
        LocaleKeys.app_errors_video_instagram_http_status,
      'instagram_no_connection' =>
        LocaleKeys.app_errors_video_instagram_no_connection,
      'instagram_interrupted' =>
        LocaleKeys.app_errors_video_instagram_interrupted,
      'not_x_url' => LocaleKeys.app_errors_video_not_x_url,
      'x_unavailable' => LocaleKeys.app_errors_video_x_unavailable,
      'x_no_video' => LocaleKeys.app_errors_video_x_no_video,
      'x_http_status' => LocaleKeys.app_errors_video_x_http_status,
      'x_no_connection' => LocaleKeys.app_errors_video_x_no_connection,
      'x_interrupted' => LocaleKeys.app_errors_video_x_interrupted,
      'stream_protected' => LocaleKeys.app_errors_video_stream_protected,
      'stream_format' => LocaleKeys.app_errors_video_stream_format,
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
