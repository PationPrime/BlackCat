import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../errors/errors.dart';

part 'mp4_muxer.dart';

/// Собирает скачанные потоки в один файл без перекодирования
abstract interface class MediaMuxerService {
  /// [inputs]: видео (если есть), затем звук — фрагментированные MP4 YouTube.
  /// [audioOnly]: собрать M4A с одной звуковой дорожкой
  Future<void> muxToMp4({
    required List<String> inputs,
    required String outputPath,
    bool audioOnly,
  });
}

class Mp4MediaMuxerServiceImpl implements MediaMuxerService {
  const Mp4MediaMuxerServiceImpl();

  @override
  Future<void> muxToMp4({
    required List<String> inputs,
    required String outputPath,
    bool audioOnly = false,
  }) async {
    try {
      await _muxToMp4(
        inputs: inputs,
        outputPath: outputPath,
        audioOnly: audioOnly,
      );
    } on FormatException catch (error) {
      throw VideoException(
        const VideoErrorCodes().mux,
        args: {'error': error.message},
      );
    }
  }
}
