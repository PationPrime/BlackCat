import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/tools/tools.dart';

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
  _format('18', ext: 'mp4', vcodec: 'avc1.42001E', acodec: 'mp4a.40.2', width: 640, height: 360),
  _format('91', ext: 'mp4', vcodec: 'avc1.4D400C', acodec: 'mp4a.40.5', width: 256, height: 144, protocol: 'm3u8_native'),
  _format('140', ext: 'm4a', acodec: 'mp4a.40.2', abr: 129, filesize: 4000),
  _format('140-1', ext: 'm4a', acodec: 'mp4a.40.2', abr: 129, filesize: 4100, languagePreference: 10),
  _format('141', ext: 'm4a', acodec: 'mp4a.40.2', abr: 255, filesize: 8000),
  _format('139', ext: 'm4a', acodec: 'mp4a.40.5', abr: 48, filesize: 1500),
  _format('251', ext: 'webm', acodec: 'opus', abr: 135, filesize: 4200, languagePreference: 10),
  _format('134', ext: 'mp4', vcodec: 'avc1.4D401E', width: 640, height: 360, fps: 25, tbr: 300, filesize: 20000),
  _format('136', ext: 'mp4', vcodec: 'avc1.4D401F', width: 1280, height: 720, fps: 25, tbr: 900),
  _format('398', ext: 'mp4', vcodec: 'av01.0.05M.08', width: 1280, height: 720, fps: 25, tbr: 700),
  _format('247', ext: 'webm', vcodec: 'vp09.00.31.08', width: 1280, height: 720, fps: 25, tbr: 800),
  _format('137', ext: 'mp4', vcodec: 'avc1.640028', width: 1920, height: 1080, fps: 25, tbr: 2500, filesize: 1.2e8),
  _format('399', ext: 'mp4', vcodec: 'av01.0.08M.08', width: 1920, height: 1080, fps: 25, tbr: 1800, filesize: null),
];

void main() {
  test('muxableRawFormats: только MP4/M4A по HTTPS с точным размером и числовым itag', () {
    final ids = [for (final format in QualitySelector.muxableRawFormats(_formats)) format['format_id']];

    expect(ids, ['140', '141', '139', '134', '136', '398']);
  });

  test('качества строятся из форматов, которые приложение склеит само', () {
    final qualities = QualitySelector.buildQualities(QualitySelector.muxableRawFormats(_formats), canMerge: true);

    expect([for (final quality in qualities) quality.id], ['720', '360', QualityModel.audioId]);
  });

  test('selectRawStreams: H.264 выше AV1 при равной частоте, AAC-звук с большим битрейтом', () {
    final streams = QualitySelector.selectRawStreams(_formats, '720');

    expect(streams.video?['format_id'], '136');
    expect(streams.audio['format_id'], '141');
  });

  test('selectRawStreams: оригинальная дорожка дублированного видео важнее битрейта', () {
    final dubbed = [
      ..._formats,
      _format('149', ext: 'm4a', acodec: 'mp4a.40.2', abr: 129, filesize: 4300, languagePreference: 10),
    ];

    expect(QualitySelector.selectRawStreams(dubbed, QualityModel.audioId).audio['format_id'], '149');
  });

  test('selectRawStreams: только звук и отсутствующее разрешение', () {
    final audioOnly = QualitySelector.selectRawStreams(_formats, QualityModel.audioId);

    expect(audioOnly.video, isNull);
    expect(audioOnly.audio['format_id'], '141');
    expect(() => QualitySelector.selectRawStreams(_formats, '1080'), throwsArgumentError);
  });
}
