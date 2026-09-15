import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../../api/api.dart';
import '../../constants/constants.dart';
import '../../errors/errors.dart';

/// Потоки видео и звука с googlevideo.com
abstract interface class RemoteMediaStreamDataSource {
  /// Скачивает [length] байт потока в [path] кусками по 10 МиБ, докачивая кусок
  /// при обрыве соединения. [onBytes] получает размер каждого полученного блока
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
    final file = await File(path).open(mode: FileMode.write);
    var written = 0;
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
            /// Сервер оборвал кусок: просим снова с места обрыва
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
