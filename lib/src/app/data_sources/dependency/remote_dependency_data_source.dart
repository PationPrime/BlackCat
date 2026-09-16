import 'dart:io';

import 'package:dio/dio.dart';

import '../../api/api.dart';

/// yt-dlp and Deno release files on GitHub
abstract interface class RemoteDependencyDataSource {
  /// A small text file, e.g. the checksum list
  Future<String> fetchText(String url, {CancelToken? cancelToken});

  /// Downloads [url] into [path], replacing it and creating missing folders.
  /// [onProgress] receives the bytes so far and the file size, `null` while
  /// it is unknown
  Future<void> downloadFile(
    String url, {
    required String path,
    required void Function(int receivedBytes, int? totalBytes) onProgress,
    CancelToken? cancelToken,
  });
}

final class RemoteDependencyDataSourceImpl
    implements RemoteDependencyDataSource {
  final ApiProvider _apiProvider;

  const RemoteDependencyDataSourceImpl({required this._apiProvider});

  @override
  Future<String> fetchText(String url, {CancelToken? cancelToken}) async {
    final response = await _apiProvider.github.dio.get<String>(
      url,
      cancelToken: cancelToken,
      options: Options(responseType: ResponseType.plain),
    );

    return response.data ?? '';
  }

  @override
  Future<void> downloadFile(
    String url, {
    required String path,
    required void Function(int receivedBytes, int? totalBytes) onProgress,
    CancelToken? cancelToken,
  }) async {
    await File(path).parent.create(recursive: true);
    await _apiProvider.github.dio.download(
      url,
      path,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) =>
          onProgress(received, total > 0 ? total : null),
    );
  }
}
