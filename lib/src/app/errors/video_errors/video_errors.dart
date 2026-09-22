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

  /// googlevideo.com answered with an error status
  final String httpStatus;

  /// The downloading stream could not be written to disk
  final String diskWrite;

  /// The disk has no room for the download
  final String diskFull;

  /// The link is not of any supported site
  final String unsupportedUrl;
  final String notRuTubeUrl;

  /// RuTube does not show the video: blocked in the country, removed,
  /// private. The reason from RuTube goes as [VideoException.reason]
  final String rutubeUnavailable;
  final String rutubeLive;
  final String rutubeHttpStatus;
  final String rutubeNoConnection;
  final String rutubeInterrupted;

  final String notTikTokUrl;

  /// TikTok does not show the video: removed, hidden, blocked in the country
  final String tiktokUnavailable;

  /// A TikTok photo post: it has no video
  final String tiktokPhoto;
  final String tiktokHttpStatus;
  final String tiktokNoConnection;
  final String tiktokInterrupted;

  final String notInstagramUrl;

  /// Instagram does not show the post without an account: removed, private
  /// or age-restricted
  final String instagramUnavailable;

  /// An Instagram post with photos only
  final String instagramPhoto;

  /// Instagram stopped showing posts without an account for a while
  final String instagramRateLimited;
  final String instagramHttpStatus;
  final String instagramNoConnection;
  final String instagramInterrupted;

  /// The video segments are encrypted
  final String streamProtected;

  /// The video comes in a format the app does not download yet
  final String streamFormat;
  final String rateLimited;
  final String webViewRuntime;
  final String jsEngine;
  final String destinationUnavailable;
  final String ytDlpNotFound;
  final String ytDlpFailed;
  final String botCheck;
  final String ageRestricted;
  final String membersOnly;
  final String privateVideo;
  final String videoUnavailable;

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
    this.httpStatus = 'http_status',
    this.diskWrite = 'disk_write',
    this.diskFull = 'disk_full',
    this.unsupportedUrl = 'unsupported_url',
    this.notRuTubeUrl = 'not_rutube_url',
    this.rutubeUnavailable = 'rutube_unavailable',
    this.rutubeLive = 'rutube_live',
    this.rutubeHttpStatus = 'rutube_http_status',
    this.rutubeNoConnection = 'rutube_no_connection',
    this.rutubeInterrupted = 'rutube_interrupted',
    this.notTikTokUrl = 'not_tiktok_url',
    this.tiktokUnavailable = 'tiktok_unavailable',
    this.tiktokPhoto = 'tiktok_photo',
    this.tiktokHttpStatus = 'tiktok_http_status',
    this.tiktokNoConnection = 'tiktok_no_connection',
    this.tiktokInterrupted = 'tiktok_interrupted',
    this.notInstagramUrl = 'not_instagram_url',
    this.instagramUnavailable = 'instagram_unavailable',
    this.instagramPhoto = 'instagram_photo',
    this.instagramRateLimited = 'instagram_rate_limited',
    this.instagramHttpStatus = 'instagram_http_status',
    this.instagramNoConnection = 'instagram_no_connection',
    this.instagramInterrupted = 'instagram_interrupted',
    this.streamProtected = 'stream_protected',
    this.streamFormat = 'stream_format',
    this.rateLimited = '429',
    this.webViewRuntime = 'web_view_runtime',
    this.jsEngine = 'js_engine',
    this.destinationUnavailable = 'destination_unavailable',
    this.ytDlpNotFound = 'ytdlp_not_found',
    this.ytDlpFailed = 'ytdlp_failed',
    this.botCheck = 'bot_check',
    this.ageRestricted = 'age_restricted',
    this.membersOnly = 'members_only',
    this.privateVideo = 'private_video',
    this.videoUnavailable = 'video_unavailable',
  });
}

/// "Video" domain exception: thrown by data sources and services,
/// turned into [VideoFailure] by [VideoErrorHandler]
final class VideoException implements Exception {
  final String code;

  /// Substitutions for the error text
  final Map<String, String> args;

  /// Ready reason text, e.g. from a YouTube response
  final String? reason;

  /// Signing in to YouTube (or refreshing the sign-in) will most likely help
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
  /// Signing in to YouTube (or refreshing the sign-in) will most likely help
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
