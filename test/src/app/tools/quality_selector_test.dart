import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/src/app/dto/dto.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/tools/tools.dart';

/// Типичный список форматов YouTube из yt-dlp (только нужные приложению поля)
const _formats = <Map<String, dynamic>>[
  {'format_id': 'sb0', 'vcodec': 'none', 'acodec': 'none', 'width': 160, 'height': 90},
  {'format_id': '140', 'vcodec': 'none', 'acodec': 'mp4a.40.2', 'abr': 129, 'filesize': 10000000},
  {'format_id': '251', 'vcodec': 'none', 'acodec': 'opus', 'abr': 135, 'filesize': 11000000},
  {'format_id': '18', 'vcodec': 'avc1.42001E', 'acodec': 'mp4a.40.2', 'width': 640, 'height': 360, 'fps': 25, 'filesize_approx': 30000000},
  {'format_id': '134', 'vcodec': 'avc1.4D401E', 'acodec': 'none', 'width': 640, 'height': 360, 'fps': 25, 'filesize': 20000000},
  {'format_id': '243', 'vcodec': 'vp09.00.21.08', 'acodec': 'none', 'width': 640, 'height': 360, 'fps': 25, 'filesize': 15000000},
  {'format_id': '136', 'vcodec': 'avc1.4D401F', 'acodec': 'none', 'width': 1280, 'height': 720, 'fps': 25, 'filesize': 60000000},
  {'format_id': '247', 'vcodec': 'vp09.00.31.08', 'acodec': 'none', 'width': 1280, 'height': 720, 'fps': 25, 'filesize': 50000000},
  {'format_id': '137', 'vcodec': 'avc1.640028', 'acodec': 'none', 'width': 1920, 'height': 1080, 'fps': 25, 'filesize': 120000000},
  {'format_id': '303', 'vcodec': 'vp09.00.41.08', 'acodec': 'none', 'width': 1920, 'height': 1080, 'fps': 50.0, 'filesize': 150000000},
  {'format_id': '313', 'vcodec': 'vp09.00.51.08', 'acodec': 'none', 'width': 3840, 'height': 2160, 'fps': 25, 'filesize_approx': 900000000},
];

Map<String, dynamic> _adaptive(
  int itag,
  String mime, {
  int? width,
  int? height,
  num? fps,
  int bitrate = 100000,
  int length = 1000,
  Map<String, dynamic> extra = const {},
}) => {
  'itag': itag,
  'mimeType': mime,
  'url': 'https://rr1.googlevideo.com/videoplayback?itag=$itag&n=CHALLENGE$itag',
  'width': ?width,
  'height': ?height,
  'fps': ?fps,
  'bitrate': bitrate,
  'contentLength': '$length',
  ...extra,
};

final _streams = PlayerResponseDto.fromJson({
  'streamingData': {
    'adaptiveFormats': [
      _adaptive(137, 'video/mp4; codecs="avc1.640028"', width: 1920, height: 1080, fps: 25, length: 160000000),
      _adaptive(248, 'video/webm; codecs="vp9"', width: 1920, height: 1080, fps: 25),
      _adaptive(399, 'video/mp4; codecs="av01.0.08M.08"', width: 1920, height: 1080, fps: 25, bitrate: 900000),
      _adaptive(136, 'video/mp4; codecs="avc1.4d401f"', width: 1280, height: 720, fps: 25),
      _adaptive(140, 'audio/mp4; codecs="mp4a.40.2"', extra: {'audioQuality': 'AUDIO_QUALITY_MEDIUM', 'audioTrack': {'audioIsDefault': false}}),
      _adaptive(140, 'audio/mp4; codecs="mp4a.40.2"', bitrate: 90000, extra: {'audioQuality': 'AUDIO_QUALITY_MEDIUM', 'audioTrack': {'audioIsDefault': true}}),
    ],
  },
}).formats;

void main() {
  group('buildQualities', () {
    test('по варианту на разрешение, от лучшего, и отдельно звук', () {
      final qualities = QualitySelector.buildQualities(_formats, canMerge: true);

      expect(qualities.map((quality) => [quality.id, quality.label]), [
        ['2160', '2160p'],
        ['1080', '1080p50'],
        ['720', '720p'],
        ['360', '360p'],
        ['audio', ''],
      ]);
      expect(qualities.last.isAac, isTrue);
    });

    test('размер — видео плюс звуковая дорожка, которая к нему приклеится', () {
      final byId = {
        for (final quality in QualitySelector.buildQualities(_formats, canMerge: true)) quality.id: quality,
      };

      expect(byId['720']!.size, 60000000 + 10000000, reason: 'H.264 при равном fps');
      expect(byId['1080']!.size, 150000000 + 10000000, reason: 'fps важнее кодека');
      expect(byId['360']!.size, 20000000 + 10000000);
      expect(byId['audio']!.size, 10000000, reason: 'предпочитается AAC');
    });

    test('без склейки доступны только форматы со звуком', () {
      expect(
        QualitySelector.buildQualities(_formats, canMerge: false).map((quality) => [quality.id, quality.size]),
        [
          ['360', 30000000],
          ['audio', 10000000],
        ],
      );
    });

    test('вертикальное видео подписывается по короткой стороне', () {
      final shorts = [
        {'vcodec': 'avc1', 'acodec': 'mp4a', 'width': 1080, 'height': 1920, 'fps': 30},
      ];

      expect(QualitySelector.buildQualities(shorts, canMerge: true).first.label, '1080p');
    });
  });

  group('потоки YouTube', () {
    test('список качеств и выбор потоков по тем же правилам', () {
      expect(QualitySelector.buildStreamQualities(_streams).map((quality) => quality.id), ['1080', '720', 'audio']);

      final hd = QualitySelector.selectStreams(_streams, '1080');

      expect(hd.video?.itag, 137, reason: 'H.264 вместо AV1 при равном fps');
      expect(hd.audio.audioIsDefault, isTrue, reason: 'оригинальная дорожка дублированного видео');
      expect(QualitySelector.selectStreams(_streams, 'audio').video, isNull);
      expect(() => QualitySelector.selectStreams(_streams, '2160'), throwsArgumentError);
    });
  });

  test('isValidQuality отбрасывает всё, что может попасть в аргументы', () {
    for (final quality in ['', '0', 'best', '720,res:1', '--exec', '99999']) {
      expect(QualitySelector.isValidQuality(quality), isFalse, reason: quality);
    }

    expect(QualitySelector.isValidQuality('1080'), isTrue);
    expect(QualitySelector.isValidQuality(QualityModel.audioId), isTrue);
  });

  test('pickDefaultQuality: лучшее разрешение не выше 1080p', () {
    QualityModel video(int resolution) =>
        QualityModel(id: '$resolution', kind: QualityKind.video, label: '${resolution}p', resolution: resolution);
    const audio = QualityModel(id: 'audio', kind: QualityKind.audio);

    expect(QualitySelector.pickDefaultQuality([video(2160), video(1080), video(720), audio]), '1080');
    expect(QualitySelector.pickDefaultQuality([audio]), 'audio');
    expect(QualitySelector.pickDefaultQuality([]), '');
  });
}
