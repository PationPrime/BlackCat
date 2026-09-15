import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../../api/api.dart';
import '../../constants/constants.dart';
import '../../errors/errors.dart';

/// Video and audio streams from googlevideo.com
abstract interface class RemoteMediaStreamDataSource {
  /// Downloads [length] bytes of the stream into [path] in 10 MiB chunks. If the file
  /// already exists, continues from its end; on a dropped connection resumes the chunk.
  /// [onBytes] receives the size of every new block
  Future<void> downloadStream(
    String url, {
    required int length,
    required String path,
    required void Function(int bytes) onBytes,
    CancelToken? cancelToken,
  });
}

final class RemoteMediaStreamDataSourceImpl
    implements RemoteMediaStreamDataSource {
  static const _maxAttempts = 4;

  final ApiProvider _apiProvider;

  const RemoteMediaStreamDataSourceImpl({required this._apiProvider});

  @override
  Future<void> downloadStream(
    String url, {
    required int length,
    required String path,
    required void Function(int bytes) onBytes,
    CancelToken? cancelToken,
  }) async {
    final existing = File(path);
    var written = await existing.exists() ? await existing.length() : 0;

    /// The file is longer than the stream, so it is not this stream: start over
    if (written > length) {
      written = 0;
    }

    final file = await existing.open(
      mode: written == 0 ? FileMode.write : FileMode.append,
    );
    var failures = 0;

    try {
      while (written < length) {
        final end =
            math.min(written + YouTubeConstants.streamChunkSize, length) - 1;

        try {
          final response = await _apiProvider.media.dio.get<ResponseBody>(
            '$url&range=$written-$end',
            cancelToken: cancelToken,
            options: Options(responseType: ResponseType.stream),
          );

          await for (final block in response.data!.stream) {
            await file.writeFrom(block);
            written += block.length;
            onBytes(block.length);
          }

          if (written <= end) {
            /// The server cut the chunk short: request again from where it stopped
            throw const _ShortReadException();
          }

          failures = 0;
        } on DioException catch (error) {
          if (error.type == DioExceptionType.cancel ||
              ++failures >= _maxAttempts ||
              error.response?.statusCode == 403) {
            rethrow;
          }

          await Future<void>.delayed(Duration(milliseconds: 500 * failures));
        } on _ShortReadException {
          if (cancelToken?.isCancelled ?? false) {
            throw DioException.requestCancelled(
              requestOptions: RequestOptions(path: url),
              reason: cancelToken!.cancelError?.error,
            );
          }

          if (++failures >= _maxAttempts) {
            throw VideoException(const VideoErrorCodes().streamInterrupted);
          }
        }
      }
    } finally {
      await file.close();
    }
  }
}

final class _ShortReadException implements Exception {
  const _ShortReadException();
}
