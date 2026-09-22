import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../errors/errors.dart';

part 'mp4_muxer.dart';
part 'ts_remuxer.dart';

/// Muxes the downloaded streams into one file without re-encoding
abstract interface class MediaMuxerService {
  /// [inputs]: video (if any), then audio: YouTube fragmented MP4 files.
  /// [audioOnly]: build an M4A with a single audio track
  Future<void> muxToMp4({
    required List<String> inputs,
    required String outputPath,
    bool audioOnly,
  });

  /// [inputs]: MPEG-TS files in playback order, e.g. HLS segments or one
  /// stream written by yt-dlp. H.264 video and AAC audio only.
  /// Runs in a separate isolate: the whole stream is read twice
  Future<void> remuxTsToMp4({
    required List<String> inputs,
    required String outputPath,
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

  @override
  Future<void> remuxTsToMp4({
    required List<String> inputs,
    required String outputPath,
  }) async {
    try {
      await Isolate.run(
        () => _remuxTsToMp4Sync(inputs: inputs, outputPath: outputPath),
        debugName: 'ts_remuxer',
      );
    } on FormatException catch (error) {
      throw VideoException(
        const VideoErrorCodes().mux,
        args: {'error': error.message},
      );
    }
  }
}
