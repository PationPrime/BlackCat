import 'dart:math' as math;

import '../dto/dto.dart';
import '../models/models.dart';
import 'quality_selector.dart';

/// Qualities of an X video: every format is one MP4 with video and audio,
/// one per resolution
abstract final class XQualities {
  /// File links name the picture and the codec: `/vid/avc1/1280x720/`
  static final _sizePattern = RegExp(r'/(\d{2,5})x(\d{2,5})/');
  static final _codecPattern = RegExp(r'/vid/([a-z0-9]+)/\d+x\d+/');

  /// Picture size of a file link. `null` when the link does not tell it
  static ({int width, int height})? sizeOfUrl(String url) {
    final match = _sizePattern.firstMatch(Uri.tryParse(url)?.path ?? url);

    return match == null
        ? null
        : (
            width: int.parse(match.group(1)!),
            height: int.parse(match.group(2)!),
          );
  }

  /// Codec of a file link: `avc1`, `hevc`…
  static String? codecOfUrl(String url) =>
      _codecPattern.firstMatch(Uri.tryParse(url)?.path ?? url)?.group(1);

  /// Short side of the picture, as for YouTube: 720 for 1280x720.
  /// `null` for a format without a picture size
  static int? resolutionOf(XFormatDto format) {
    final width = format.width;
    final height = format.height;

    if (height == null || height <= 0) return null;

    return width == null || width <= 0 ? height : math.min(width, height);
  }

  /// One option per resolution, best to worst. A codec other than H.264
  /// is named: not every player plays it
  static List<QualityModel> build(List<XFormatDto> formats) {
    final best = _bestByResolution(formats);
    final resolutions = best.keys.toList()..sort((a, b) => b - a);

    return [
      for (final resolution in resolutions)
        QualityModel(
          id: '$resolution',
          kind: QualityKind.video,
          label: '${resolution}p${_codecSuffix(best[resolution]!)}',
          resolution: resolution,
          size: best[resolution]!.size,
        ),
    ];
  }

  /// Format to download. The format of the previous run wins while the post
  /// still has it: its bytes are already on disk. Returns `null` if the post
  /// has no such quality
  static XFormatDto? select(
    List<XFormatDto> formats, {
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

  static String _codecSuffix(XFormatDto format) {
    final codec = format.codec?.toLowerCase() ?? '';

    return codec.isEmpty || codec.startsWith('avc') || codec == 'h264'
        ? ''
        : ' · ${codec == 'hevc' ? 'H.265' : codec.toUpperCase()}';
  }

  /// The higher bitrate of the same resolution
  static Map<int, XFormatDto> _bestByResolution(List<XFormatDto> formats) {
    final best = <int, XFormatDto>{};

    for (final format in formats) {
      final resolution = resolutionOf(format);

      if (resolution == null || format.url.isEmpty) continue;

      final current = best[resolution];

      if (current == null || format.bitrate > current.bitrate) {
        best[resolution] = format;
      }
    }

    return best;
  }
}
