import 'dart:math' as math;

import '../dto/dto.dart';
import '../models/models.dart';

typedef RawFormat = Map<String, dynamic>;

/// Список качеств и выбор потоков для скачивания
abstract final class QualitySelector {
  static final _h264Pattern = RegExp(r'^(avc1|h264)', caseSensitive: false);
  static final _aacPattern = RegExp(r'^mp4a', caseSensitive: false);
  static final _resolutionIdPattern = RegExp(r'^[1-9]\d{1,3}$');

  /// Превращает список форматов в формате yt-dlp в короткий список для экрана:
  /// по варианту на разрешение (от лучшего к худшему) и отдельно звук.
  /// Без склейки ([canMerge] = `false`) доступны только форматы со звуком
  static List<QualityModel> buildQualities(
    List<RawFormat> formats, {
    required bool canMerge,
  }) {
    final audio = _pickRawAudio(formats);
    final bestByResolution = <int, RawFormat>{};

    for (final format in formats) {
      if (!_hasVideo(format) ||
          _num(format['height']) == null ||
          (!canMerge && !_hasAudio(format))) {
        continue;
      }

      final resolution = _resolutionOf(format);
      final current = bestByResolution[resolution];

      if (current == null || _isBetterCandidate(format, current)) {
        bestByResolution[resolution] = format;
      }
    }

    final resolutions = bestByResolution.keys.toList()
      ..sort((left, right) => right - left);

    final qualities = [
      for (final resolution in resolutions)
        () {
          final format = bestByResolution[resolution]!;
          final videoSize = _sizeOf(format);
          final audioSize = _hasAudio(format)
              ? 0
              : (audio == null ? null : _sizeOf(audio));

          return QualityModel(
            id: '$resolution',
            kind: QualityKind.video,
            label: '${resolution}p${_fpsSuffix(format)}',
            resolution: resolution,
            size: videoSize != null && audioSize != null
                ? videoSize + audioSize
                : null,
          );
        }(),
    ];

    if (audio != null) {
      qualities.add(
        QualityModel(
          id: QualityModel.audioId,
          kind: QualityKind.audio,
          size: _sizeOf(audio),
          isAac: _aacPattern.hasMatch(audio['acodec'] as String? ?? ''),
        ),
      );
    }

    return qualities;
  }

  /// Качества для MP4-потоков YouTube: видео и звук приложение склеивает само
  static List<QualityModel> buildStreamQualities(
    List<StreamFormatDto> formats,
  ) => buildQualities([
    for (final format in formats) format.toRawFormat(),
  ], canMerge: true);

  static bool isValidQuality(String quality) =>
      quality == QualityModel.audioId || _resolutionIdPattern.hasMatch(quality);

  /// Лучшее разрешение не выше 1080p, иначе первый вариант
  static String pickDefaultQuality(List<QualityModel> qualities) {
    final preferred = qualities.where(
      (quality) => quality.kind.isVideo && quality.resolution! <= 1080,
    );

    return (preferred.firstOrNull ?? qualities.firstOrNull)?.id ?? '';
  }

  /// Потоки для качества из [buildStreamQualities]: видео и звук или только звук
  static ({StreamFormatDto? video, StreamFormatDto audio}) selectStreams(
    List<StreamFormatDto> formats,
    String quality,
  ) {
    final audio = _bestAudioStream(formats);

    if (audio == null) {
      throw ArgumentError('no MP4 audio stream');
    }

    if (quality == QualityModel.audioId) {
      return (video: null, audio: audio);
    }

    final resolution = int.parse(quality);
    final candidates = formats
        .where(
          (format) =>
              format.hasVideo && !format.hasAudio && format.height != null,
        )
        .where(
          (format) =>
              math.min(
                format.width == null || format.width == 0
                    ? format.height!
                    : format.width!,
                format.height!,
              ) ==
              resolution,
        )
        .toList();

    if (candidates.isEmpty) {
      throw ArgumentError('no $quality video stream');
    }

    /// Тот же порядок, что у списка качеств: выше fps, затем H.264, затем битрейт
    candidates.sort((left, right) {
      final byFps = (right.fps ?? 0).compareTo(left.fps ?? 0);

      if (byFps != 0) return byFps;

      final byCodec =
          (_isH264Codec(right.videoCodec) ? 1 : 0) -
          (_isH264Codec(left.videoCodec) ? 1 : 0);

      if (byCodec != 0) return byCodec;

      return (right.bitrate ?? 0).compareTo(left.bitrate ?? 0);
    });

    return (video: candidates.first, audio: audio);
  }

  static StreamFormatDto? _bestAudioStream(List<StreamFormatDto> formats) {
    final audio =
        formats.where((format) => format.hasAudio && !format.hasVideo).toList()
          ..sort((left, right) {
            /// Оригинальная дорожка дублированного видео, затем AAC, затем битрейт
            final byDefault =
                (right.audioIsDefault ? 1 : 0) - (left.audioIsDefault ? 1 : 0);

            if (byDefault != 0) return byDefault;

            final byCodec =
                (_aacPattern.hasMatch(right.audioCodec ?? '') ? 1 : 0) -
                (_aacPattern.hasMatch(left.audioCodec ?? '') ? 1 : 0);

            if (byCodec != 0) return byCodec;

            return (right.bitrate ?? 0).compareTo(left.bitrate ?? 0);
          });

    return audio.firstOrNull;
  }

  static num? _num(Object? value) => value is num ? value : null;

  static bool _hasCodec(Object? codec) =>
      codec is String && codec.isNotEmpty && codec != 'none';

  static bool _hasVideo(RawFormat format) => _hasCodec(format['vcodec']);

  static bool _hasAudio(RawFormat format) => _hasCodec(format['acodec']);

  static bool _isH264Codec(String? codec) => _h264Pattern.hasMatch(codec ?? '');

  static num _fps(RawFormat format) => _num(format['fps']) ?? 0;

  static int? _sizeOf(RawFormat format) =>
      (_num(format['filesize']) ?? _num(format['filesize_approx']))?.round();

  /// Короткая сторона кадра: вертикальное видео (Shorts) подписывается 1080p, а не 1920p
  static int _resolutionOf(RawFormat format) {
    final height = _num(format['height'])!;
    final width = _num(format['width']);

    return math.min(width == null || width == 0 ? height : width, height).round();
  }

  /// Выше fps, затем H.264 вместо VP9/AV1, затем битрейт
  static bool _isBetterCandidate(RawFormat candidate, RawFormat current) {
    if (_fps(candidate) != _fps(current)) {
      return _fps(candidate) > _fps(current);
    }

    final candidateIsH264 = _isH264Codec(candidate['vcodec'] as String?);
    final currentIsH264 = _isH264Codec(current['vcodec'] as String?);

    if (candidateIsH264 != currentIsH264) {
      return candidateIsH264;
    }

    return (_num(candidate['tbr']) ?? 0) > (_num(current['tbr']) ?? 0);
  }

  static RawFormat? _pickRawAudio(List<RawFormat> formats) {
    final audio =
        formats
            .where((format) => _hasAudio(format) && !_hasVideo(format))
            .toList()
          ..sort((left, right) {
            final byCodec =
                (_aacPattern.hasMatch(right['acodec'] as String? ?? '') ? 1 : 0) -
                (_aacPattern.hasMatch(left['acodec'] as String? ?? '') ? 1 : 0);

            return byCodec != 0
                ? byCodec
                : (_num(right['abr']) ?? 0).compareTo(_num(left['abr']) ?? 0);
          });

    return audio.firstOrNull;
  }

  static String _fpsSuffix(RawFormat format) {
    final fps = _fps(format);

    return fps > 30
        ? (fps == fps.roundToDouble() ? '${fps.round()}' : '$fps')
        : '';
  }
}
