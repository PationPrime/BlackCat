import 'dart:math' as math;

import '../dto/dto.dart';
import '../models/models.dart';
import 'quality_selector.dart';

/// What to download for a quality: a ready file, or DASH video with the
/// audio it is muxed with
typedef InstagramChoice = ({
  InstagramStreamDto video,
  InstagramStreamDto? audio,
});

/// Qualities of an Instagram video. A post has a ready MP4 file (H.264 with
/// audio) and DASH streams of more resolutions, often only in VP9
abstract final class InstagramQualities {
  /// Short side of the picture, as for YouTube: 1080 for 1080x1920.
  /// `null` for a stream without a picture size
  static int? resolutionOf(InstagramStreamDto stream) {
    final width = stream.width;
    final height = stream.height;

    if (!stream.hasVideo || height == null || height <= 0) return null;

    return width == null || width <= 0 ? height : math.min(width, height);
  }

  /// The audio muxed with DASH video: AAC of the highest bitrate.
  /// `null` for a video without sound
  static InstagramStreamDto? audioOf(List<InstagramStreamDto> streams) {
    InstagramStreamDto? best;

    for (final stream in streams) {
      if (stream.kind != InstagramStreamKind.audio ||
          !(stream.codec?.toLowerCase().startsWith('mp4a') ?? true)) {
        continue;
      }

      if (best == null || (stream.bandwidth ?? 0) > (best.bandwidth ?? 0)) {
        best = stream;
      }
    }

    return best;
  }

  /// One option per resolution, best to worst. A codec other than H.264
  /// is named: not every player plays it
  static List<QualityModel> build(List<InstagramStreamDto> streams) {
    final best = _bestByResolution(streams);
    final audio = audioOf(streams);
    final resolutions = best.keys.toList()..sort((a, b) => b - a);

    return [
      for (final resolution in resolutions)
        QualityModel(
          id: '$resolution',
          kind: QualityKind.video,
          label: '${resolution}p${_codecSuffix(best[resolution]!)}',
          resolution: resolution,
          size: sizeOf((
            video: best[resolution]!,
            audio: best[resolution]!.kind == InstagramStreamKind.video
                ? audio
                : null,
          )),
        ),
    ];
  }

  /// Streams to download. The video stream of the previous run wins while
  /// the post still has it: its bytes are already on disk. Returns `null`
  /// if the post has no such quality
  static InstagramChoice? select(
    List<InstagramStreamDto> streams, {
    required String quality,
    int? previousVideoKey,
  }) {
    final audio = audioOf(streams);

    InstagramChoice choiceOf(InstagramStreamDto video) => (
      video: video,
      audio: video.kind == InstagramStreamKind.video ? audio : null,
    );

    if (previousVideoKey != null) {
      final previous = streams
          .where((stream) => stream.hasVideo && stream.key == previousVideoKey)
          .firstOrNull;

      if (previous != null) return choiceOf(previous);
    }

    if (!QualitySelector.isValidQuality(quality) ||
        quality == QualityModel.audioId) {
      return null;
    }

    return switch (_bestByResolution(streams)[int.parse(quality)]) {
      final video? => choiceOf(video),
      null => null,
    };
  }

  /// Bytes of a choice, when every stream of it tells its size
  static int? sizeOf(InstagramChoice choice) {
    final videoSize = choice.video.size;

    if (choice.video.kind != InstagramStreamKind.video) return videoSize;

    final audioSize = choice.audio == null ? 0 : choice.audio!.size;

    return videoSize == null || audioSize == null
        ? null
        : videoSize + audioSize;
  }

  static String _codecSuffix(InstagramStreamDto stream) {
    final codec = stream.codec?.toLowerCase() ?? '';

    return switch (codec) {
      _ when stream.isH264 || codec.isEmpty => '',
      _ when codec.startsWith('vp09') || codec.startsWith('vp9') => ' · VP9',
      _ when codec.startsWith('av01') => ' · AV1',
      _ when codec.startsWith('hvc1') || codec.startsWith('hev1') => ' · H.265',
      _ => ' · ${codec.split('.').first.toUpperCase()}',
    };
  }

  /// A ready file before DASH, H.264 before other codecs, then the higher
  /// bitrate
  static Map<int, InstagramStreamDto> _bestByResolution(
    List<InstagramStreamDto> streams,
  ) {
    final best = <int, InstagramStreamDto>{};

    int rank(InstagramStreamDto stream) =>
        (stream.isH264 ? 2 : 0) +
        (stream.kind == InstagramStreamKind.file ? 1 : 0);

    for (final stream in streams) {
      final resolution = resolutionOf(stream);

      if (resolution == null || stream.url.isEmpty) continue;

      final current = best[resolution];

      if (current == null ||
          rank(stream) > rank(current) ||
          (rank(stream) == rank(current) &&
              (stream.bandwidth ?? stream.size ?? 0) >
                  (current.bandwidth ?? current.size ?? 0))) {
        best[resolution] = stream;
      }
    }

    return best;
  }
}
