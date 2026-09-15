import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../errors/errors.dart';

part 'mp4_muxer.dart';

/// Muxes the downloaded streams into one file without re-encoding
abstract interface class MediaMuxerService {
  /// [inputs]: video (if any), then audio: YouTube fragmented MP4 files.
  /// [audioOnly]: build an M4A with a single audio track
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
