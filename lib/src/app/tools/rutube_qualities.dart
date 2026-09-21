import 'dart:math' as math;

import '../models/models.dart';
import 'hls_playlist.dart';
import 'quality_selector.dart';

/// Qualities of a RuTube video: every HLS variant has video and audio
/// together, and each one comes from two CDNs with the same bitrate
abstract final class RuTubeQualities {
  /// Short side of the picture, as for YouTube: 1080 for both 1920x1080
  /// and 1080x1920. `null` for a variant without a picture size
  static int? resolutionOf(HlsVariant variant) {
    final width = variant.width;
    final height = variant.height;

    if (height == null || height <= 0) return null;

    return width == null || width <= 0 ? height : math.min(width, height);
  }

  /// Bytes the variant takes: bitrate × duration. `null` without a duration
  static int? expectedBytes(HlsVariant variant, num? durationSeconds) =>
      durationSeconds == null || durationSeconds <= 0
      ? null
      : (variant.bandwidth / 8 * durationSeconds).round();

  /// One option per resolution, best to worst, with the size estimated
  /// from the bitrate of the best variant of the resolution
  static List<QualityModel> build(
    List<HlsVariant> variants, {
    num? durationSeconds,
  }) {
    final best = _bestByResolution(variants);
    final resolutions = best.keys.toList()..sort((a, b) => b - a);

    return [
      for (final resolution in resolutions)
        QualityModel(
          id: '$resolution',
          kind: QualityKind.video,
          label: '${resolution}p${_fpsSuffix(best[resolution]!)}',
          resolution: resolution,
          size: expectedBytes(best[resolution]!, durationSeconds),
        ),
    ];
  }

  /// Variant to download. The variant of the previous run wins while the
  /// video still has it: its segments are already on disk. Returns `null`
  /// if the video has no such quality
  static HlsVariant? select(
    List<HlsVariant> variants, {
    required String quality,
    int? previousBandwidth,
  }) {
    if (previousBandwidth != null) {
      final previous = variants
          .where((variant) => variant.bandwidth == previousBandwidth)
          .firstOrNull;

      if (previous != null) return previous;
    }

    if (!QualitySelector.isValidQuality(quality) ||
        quality == QualityModel.audioId) {
      return null;
    }

    return _bestByResolution(variants)[int.parse(quality)];
  }

  /// The highest bitrate of each resolution; the first CDN of equal ones
  static Map<int, HlsVariant> _bestByResolution(List<HlsVariant> variants) {
    final best = <int, HlsVariant>{};

    for (final variant in variants) {
      final resolution = resolutionOf(variant);

      if (resolution == null) continue;

      final current = best[resolution];

      if (current == null || variant.bandwidth > current.bandwidth) {
        best[resolution] = variant;
      }
    }

    return best;
  }

  static String _fpsSuffix(HlsVariant variant) {
    final fps = variant.frameRate;

    return fps != null && fps > 30 ? '${fps.round()}' : '';
  }
}
