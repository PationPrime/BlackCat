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

/// TikTok video pages and their files. TikTok gives the page data and the
/// file links to a browser; the links are checked against the page cookies
final class TikTokApiClient extends ApiClient {
  TikTokApiClient({super.interceptors})
    : super(
        headers: const {
          'User-Agent': YouTubeConstants.browserUserAgent,
          'Accept-Language': 'en-US,en;q=0.9',
        },
      );
}

/// Instagram post pages and their files. The page carries the post data only
/// for a browser that opens it: the page requests say so
final class InstagramApiClient extends ApiClient {
  InstagramApiClient({super.interceptors})
    : super(
        headers: const {
          'User-Agent': YouTubeConstants.browserUserAgent,
          'Accept-Language': 'en-US,en;q=0.9',
          'Referer': '${InstagramConstants.origin}/',
        },
      );
}

/// X posts from the embed (syndication) API and their video files
final class XApiClient extends ApiClient {
  XApiClient({super.interceptors})
    : super(
        headers: const {
          'User-Agent': YouTubeConstants.browserUserAgent,
          'Accept-Language': 'en-US,en;q=0.9',
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
  late final TikTokApiClient tiktok;
  late final InstagramApiClient instagram;
  late final XApiClient x;
  late final GitHubApiClient github;

  ApiProvider({List<Interceptor> interceptors = const []}) {
    _init(interceptors: interceptors);
  }

  void _init({required List<Interceptor> interceptors}) {
    try {
      youtube = YouTubeApiClient(interceptors: interceptors);
      media = MediaApiClient(interceptors: interceptors);
      rutube = RuTubeApiClient(interceptors: interceptors);
      tiktok = TikTokApiClient(interceptors: interceptors);
      instagram = InstagramApiClient(interceptors: interceptors);
      x = XApiClient(interceptors: interceptors);
      github = GitHubApiClient(interceptors: interceptors);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        Exception('Init API Provider error: $error'),
        stackTrace,
      );
    }
  }
}
