import 'package:flutter_test/flutter_test.dart';
import 'package:peeky_cat/src/app/models/models.dart';
import 'package:peeky_cat/src/app/tools/tools.dart';

Map<String, dynamic> _format(
  String id, {
  required String ext,
  String vcodec = 'none',
  String acodec = 'none',
  int? width,
  int? height,
  num? fps,
  num? tbr,
  num? abr,
  Object? filesize = 1000,
  String protocol = 'https',
  int? languagePreference,
}) => {
  'format_id': id,
  'ext': ext,
  'protocol': protocol,
  'vcodec': vcodec,
  'acodec': acodec,
  'width': ?width,
  'height': ?height,
  'fps': ?fps,
  'tbr': ?tbr,
  'abr': ?abr,
  'filesize': filesize,
  'language_preference': ?languagePreference,
};

/// yt-dlp formats of one video: DASH MP4/M4A and everything the app skips
final _formats = [
  _format('sb0', ext: 'mhtml', filesize: null, protocol: 'mhtml'),
  _format(
    '18',
    ext: 'mp4',
    vcodec: 'avc1.42001E',
    acodec: 'mp4a.40.2',
    width: 640,
    height: 360,
  ),
  _format(
    '91',
    ext: 'mp4',
    vcodec: 'avc1.4D400C',
    acodec: 'mp4a.40.5',
    width: 256,
    height: 144,
    protocol: 'm3u8_native',
  ),
  _format(
    'hls-1080p',
    ext: 'mp4',
    vcodec: 'avc1.640028',
    width: 1920,
    height: 1080,
    protocol: 'https',
  ),
  _format('140', ext: 'm4a', acodec: 'mp4a.40.2', abr: 129, filesize: 4000),
  _format('141', ext: 'm4a', acodec: 'mp4a.40.2', abr: 255, filesize: 8000),
  _format('139', ext: 'm4a', acodec: 'mp4a.40.5', abr: 48, filesize: 1500),
  _format('251', ext: 'webm', acodec: 'opus', abr: 135, filesize: 4200),
  _format(
    '134',
    ext: 'mp4',
    vcodec: 'avc1.4D401E',
    width: 640,
    height: 360,
    fps: 25,
    tbr: 300,
    filesize: 20000,
  ),
  _format(
    '136',
    ext: 'mp4',
    vcodec: 'avc1.4D401F',
    width: 1280,
    height: 720,
    fps: 25,
    tbr: 900,
  ),
  _format(
    '398',
    ext: 'mp4',
    vcodec: 'av01.0.05M.08',
    width: 1280,
    height: 720,
    fps: 25,
    tbr: 700,
  ),
  _format(
    '247',
    ext: 'webm',
    vcodec: 'vp09.00.31.08',
    width: 1280,
    height: 720,
    fps: 25,
    tbr: 800,
  ),
  _format(
    '137',
    ext: 'mp4',
    vcodec: 'avc1.640028',
    width: 1920,
    height: 1080,
    fps: 25,
    tbr: 2500,
    filesize: 1.2e8,
  ),
  _format(
    '399',
    ext: 'mp4',
    vcodec: 'av01.0.08M.08',
    width: 1920,
    height: 1080,
    fps: 25,
    tbr: 1800,
    filesize: null,
  ),
];

/// A video with YouTube auto-dubbing, as yt-dlp 2026.08 lists it: the same
/// itag for every audio track, numbered after a dash; the original track
/// has `language_preference` 10
final _dubbedFormats = [
  _format(
    '140-0',
    ext: 'm4a',
    acodec: 'mp4a.40.2',
    abr: 129.484,
    filesize: 7743522,
    languagePreference: -1,
  ),
  _format(
    '140-1',
    ext: 'm4a',
    acodec: 'mp4a.40.2',
    abr: 129.491,
    filesize: 7743244,
    languagePreference: 10,
  ),
  _format(
    '251-0',
    ext: 'webm',
    acodec: 'opus',
    abr: 123,
    filesize: 7356590,
    languagePreference: -1,
  ),
  _format(
    '251-1',
    ext: 'webm',
    acodec: 'opus',
    abr: 136,
    filesize: 8157611,
    languagePreference: 10,
  ),
  _format(
    '160',
    ext: 'mp4',
    vcodec: 'avc1.4d400c',
    width: 256,
    height: 144,
    fps: 25,
    filesize: 6609946,
  ),
  _format(
    '137',
    ext: 'mp4',
    vcodec: 'avc1.640028',
    width: 1920,
    height: 1080,
    fps: 25,
    filesize: 167914982,
  ),
];

void main() {
  test(
    'itagOf: itag из идентификатора yt-dlp, включая дорожки, DRC и апскейл',
    () {
      int? itag(String id) => QualitySelector.itagOf({'format_id': id});

      expect(itag('140'), 140);
      expect(itag('140-1'), 140);
      expect(itag('140-drc'), 140);
      expect(itag('251-drc-1'), 251);
      expect(itag('137-sr'), 137);
      expect(itag('616'), 616);
      expect(itag('sb0'), isNull);
      expect(itag('hls-1080p'), isNull);
      expect(itag('137+140'), isNull);
    },
  );

  test(
    'muxableRawFormats: только MP4/M4A по HTTPS с точным размером и itag',
    () {
      final ids = [
        for (final format in QualitySelector.muxableRawFormats(_formats))
          format['format_id'],
      ];

      expect(ids, ['140', '141', '139', '134', '136', '398']);
      expect(
        [
          for (final format in QualitySelector.muxableRawFormats(
            _dubbedFormats,
          ))
            format['format_id'],
        ],
        ['140-0', '140-1', '160', '137'],
      );
    },
  );

  test('качества строятся из форматов, которые приложение склеит само', () {
    final qualities = QualitySelector.buildQualities(
      QualitySelector.muxableRawFormats(_formats),
      canMerge: true,
    );

    expect(
      [for (final quality in qualities) quality.id],
      ['720', '360', QualityModel.audioId],
    );
  });

  test(
    'selectRawStreams: H.264 выше AV1 при равной частоте, AAC-звук с большим битрейтом',
    () {
      final streams = QualitySelector.selectRawStreams(_formats, '720');

      expect(streams.video?['format_id'], '136');
      expect(streams.audio['format_id'], '141');
    },
  );

  test(
    'дублированное видео: качества есть, скачивается оригинальная дорожка, её размер и показывается',
    () {
      final qualities = QualitySelector.buildQualities(
        QualitySelector.muxableRawFormats(_dubbedFormats),
        canMerge: true,
      );

      expect(
        [for (final quality in qualities) quality.id],
        ['1080', '144', QualityModel.audioId],
      );
      expect(qualities.first.size, 167914982 + 7743244);
      expect(qualities.last.size, 7743244);

      final streams = QualitySelector.selectRawStreams(_dubbedFormats, '1080');

      expect(streams.video?['format_id'], '137');
      expect(streams.audio['format_id'], '140-1');
    },
  );

  test('сжатый звук (DRC) и апскейл берутся, только если нет оригинала', () {
    final variants = [
      _format(
        '140-drc',
        ext: 'm4a',
        acodec: 'mp4a.40.2',
        abr: 140,
        filesize: 5000,
      ),
      _format('140', ext: 'm4a', acodec: 'mp4a.40.2', abr: 129, filesize: 4000),
      _format(
        '137-sr',
        ext: 'mp4',
        vcodec: 'avc1.640028',
        width: 1920,
        height: 1080,
        fps: 30,
        tbr: 3000,
      ),
      _format(
        '137',
        ext: 'mp4',
        vcodec: 'avc1.640028',
        width: 1920,
        height: 1080,
        fps: 30,
        tbr: 2500,
      ),
    ];

    final streams = QualitySelector.selectRawStreams(variants, '1080');

    expect(streams.audio['format_id'], '140');
    expect(streams.video?['format_id'], '137');

    final onlyVariants = [variants[0], variants[2]];

    expect(
      QualitySelector.selectRawStreams(
        onlyVariants,
        '1080',
      ).video?['format_id'],
      '137-sr',
    );
    expect(
      QualitySelector.selectRawStreams(onlyVariants, '1080').audio['format_id'],
      '140-drc',
    );
  });

  test('без звуковой дорожки видео не предлагается: склеивать не с чем', () {
    final videoOnly = [
      _format(
        '137',
        ext: 'mp4',
        vcodec: 'avc1.640028',
        width: 1920,
        height: 1080,
        fps: 25,
      ),
    ];

    expect(QualitySelector.buildQualities(videoOnly, canMerge: true), isEmpty);
    expect(
      () => QualitySelector.selectRawStreams(videoOnly, '1080'),
      throwsArgumentError,
    );
  });

  test('selectRawStreams: только звук и отсутствующее разрешение', () {
    final audioOnly = QualitySelector.selectRawStreams(
      _formats,
      QualityModel.audioId,
    );

    expect(audioOnly.video, isNull);
    expect(audioOnly.audio['format_id'], '141');
    expect(
      () => QualitySelector.selectRawStreams(_formats, '1080'),
      throwsArgumentError,
    );
  });
}
