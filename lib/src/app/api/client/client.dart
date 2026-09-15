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

base class ApiProvider {
  late final YouTubeApiClient youtube;
  late final MediaApiClient media;

  ApiProvider({List<Interceptor> interceptors = const []}) {
    _init(interceptors: interceptors);
  }

  void _init({required List<Interceptor> interceptors}) {
    try {
      youtube = YouTubeApiClient(interceptors: interceptors);
      media = MediaApiClient(interceptors: interceptors);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        Exception('Init API Provider error: $error'),
        stackTrace,
      );
    }
  }
}
