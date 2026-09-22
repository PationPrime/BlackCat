import 'package:dio/dio.dart';

import '../../constants/constants.dart';
import 'base_client.dart';

/// YouTube pages and API
final class YouTubeApiClient extends ApiClient {
  YouTubeApiClient({super.interceptors})
    : super(headers: const {'User-Agent': YouTubeConstants.browserUserAgent});
}

/// Video and audio streams from googlevideo.com
final class MediaApiClient extends ApiClient {
  MediaApiClient({super.interceptors})
    : super(
        headers: const {
          'User-Agent': YouTubeConstants.browserUserAgent,
          'Origin': YouTubeConstants.origin,
          'Referer': '${YouTubeConstants.origin}/',
        },
      );
}

/// RuTube player API, HLS playlists and segments
final class RuTubeApiClient extends ApiClient {
  RuTubeApiClient({super.interceptors})
    : super(
        headers: const {
          'User-Agent': YouTubeConstants.browserUserAgent,
          'Origin': RuTubeConstants.origin,
          'Referer': '${RuTubeConstants.origin}/',
        },
      );
}

/// yt-dlp and Deno releases on GitHub
final class GitHubApiClient extends ApiClient {
  static const _userAgent = 'YT-Download';

  GitHubApiClient({super.interceptors})
    : super(headers: const {'User-Agent': _userAgent});
}

base class ApiProvider {
  late final YouTubeApiClient youtube;
  late final MediaApiClient media;
  late final RuTubeApiClient rutube;
  late final GitHubApiClient github;

  ApiProvider({List<Interceptor> interceptors = const []}) {
    _init(interceptors: interceptors);
  }

  void _init({required List<Interceptor> interceptors}) {
    try {
      youtube = YouTubeApiClient(interceptors: interceptors);
      media = MediaApiClient(interceptors: interceptors);
      rutube = RuTubeApiClient(interceptors: interceptors);
      github = GitHubApiClient(interceptors: interceptors);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        Exception('Init API Provider error: $error'),
        stackTrace,
      );
    }
  }
}
