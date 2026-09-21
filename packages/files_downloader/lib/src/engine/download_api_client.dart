import 'package:dio/dio.dart';

import '../models/download_options.dart';

/// HTTP client of a download, created inside the download isolate:
/// a dio instance with the download's headers and timeouts.
///
/// Every request asks for the raw bytes (`Accept-Encoding: identity`):
/// compressed transfers break byte offsets
base class DownloadApiClient {
  final Dio dio;

  DownloadApiClient(FilesDownloadOptions options, {HttpClientAdapter? adapter})
    : dio = Dio(
        BaseOptions(
          headers: {...options.headers, 'accept-encoding': 'identity'},
          connectTimeout: options.connectTimeout,
          responseType: ResponseType.stream,
          followRedirects: true,
          maxRedirects: 5,

          /// Statuses are checked by the downloader
          validateStatus: (_) => true,
        ),
      ) {
    if (adapter != null) dio.httpClientAdapter = adapter;
  }

  void close() => dio.close(force: true);
}
