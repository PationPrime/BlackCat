import 'dart:math' as math;

import '../dto/dto.dart';
import '../models/models.dart';
import 'quality_selector.dart';

/// Qualities of a TikTok video: every format is one MP4 with video and audio.
/// A resolution often comes in H.264 and H.265, and in several bitrates
abstract final class TikTokQualities {
  /// Short side of the picture, as for YouTube: 1080 for 1080x1920.
  /// `null` for a format without a picture size
  static int? resolutionOf(TikTokFormatDto format) {
    final width = format.width;
    final height = format.height;

    if (height == null || height <= 0) return null;

    return width == null || width <= 0 ? height : math.min(width, height);
  }

  /// One option per resolution, best to worst. H.265 is marked:
  /// not every player plays it
  static List<QualityModel> build(List<TikTokFormatDto> formats) {
    final best = _bestByResolution(formats);
    final resolutions = best.keys.toList()..sort((a, b) => b - a);

    return [
      for (final resolution in resolutions)
        QualityModel(
          id: '$resolution',
          kind: QualityKind.video,
          label: '${resolution}p${best[resolution]!.isHevc ? ' · H.265' : ''}',
          resolution: resolution,
          size: best[resolution]!.size,
        ),
    ];
  }

  /// Format to download. The format of the previous run wins while the video
  /// still has it: its bytes are already on disk. Returns `null` if the video
  /// has no such quality
  static TikTokFormatDto? select(
    List<TikTokFormatDto> formats, {
    required String quality,
    int? previousBitrate,
  }) {
    if (previousBitrate != null) {
      final previous = formats
          .where((format) => format.bitrate == previousBitrate)
          .firstOrNull;

      if (previous != null) return previous;
    }

    if (!QualitySelector.isValidQuality(quality) ||
        quality == QualityModel.audioId) {
      return null;
    }

    return _bestByResolution(formats)[int.parse(quality)];
  }

  /// H.264 before H.265 of the same resolution, then the higher bitrate
  static Map<int, TikTokFormatDto> _bestByResolution(
    List<TikTokFormatDto> formats,
  ) {
    final best = <int, TikTokFormatDto>{};

    for (final format in formats) {
      final resolution = resolutionOf(format);

      if (resolution == null || format.urls.isEmpty) continue;

      final current = best[resolution];

      if (current == null ||
          (current.isHevc && !format.isHevc) ||
          (current.isHevc == format.isHevc &&
              format.bitrate > current.bitrate)) {
        best[resolution] = format;
      }
    }

    return best;
  }
}
