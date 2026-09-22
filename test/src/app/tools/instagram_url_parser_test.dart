import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:peeky_cat/src/app/dto/dto.dart';
import 'package:peeky_cat/src/app/models/models.dart';
import 'package:peeky_cat/src/app/tools/tools.dart';

import '../../support/dash_stream_builder.dart';
import '../../support/mp4_file_builder.dart';

const _code = 'DZT71H-BJuK';

InstagramStreamDto _stream(
  InstagramStreamKind kind, {
  required int key,
  String? codec,
  int? width,
  int? height,
  int? size,
  int? bandwidth,
}) => InstagramStreamDto(
  kind: kind,
  url: 'https://cdn/$key.mp4',
  key: key,
  codec: codec,
  width: width,
  height: height,
  size: size,
  bandwidth: bandwidth,
);

/// A ready file, 720p and 1080p in DASH VP9 and AAC: as a reel gives them
final _reelStreams = [
  _stream(
    InstagramStreamKind.file,
    key: 438095,
    codec: 'avc1',
    width: 720,
    height: 1280,
    size: 438095,
  ),
  _stream(
    InstagramStreamKind.video,
    key: 1211135347711936,
    codec: 'vp09.00.31.08',
    width: 720,
    height: 1280,
    size: 252703,
    bandwidth: 202838,
  ),
  _stream(
    InstagramStreamKind.video,
    key: 1654544069172785,
    codec: 'vp09.00.40.08',
    width: 1080,
    height: 1920,
    size: 492039,
    bandwidth: 394947,
  ),
  _stream(
    InstagramStreamKind.audio,
    key: 989422917031360,
    codec: 'mp4a.40.5',
    size: 73743,
    bandwidth: 58361,
  ),
];

void main() {
  test('ссылка на рилс: параметры отбрасываются', () {
    final link = InstagramUrlParser.parse(
      'https://www.instagram.com/reel/$_code/?hl=en&igsh=abc',
    );

    expect(link?.code, _code);
    expect(link?.kind, InstagramPostKind.reel);
    expect(link?.isShare, isFalse);
    expect(link?.url, 'https://www.instagram.com/reel/$_code/');
  });

  for (final (url, expected) in [
    (
      'https://instagram.com/reels/$_code',
      'https://www.instagram.com/reel/$_code/',
    ),
    (
      'https://www.instagram.com/wasted/reel/$_code/',
      'https://www.instagram.com/reel/$_code/',
    ),
    (
      'https://www.instagram.com/p/$_code/?img_index=1',
      'https://www.instagram.com/p/$_code/',
    ),
    (
      'https://m.instagram.com/tv/$_code',
      'https://www.instagram.com/tv/$_code/',
    ),
    ('  http://instagr.am/p/$_code/  ', 'https://www.instagram.com/p/$_code/'),
  ]) {
    test('принимает ${url.trim()}', () {
      expect(InstagramUrlParser.parse(url)?.url, expected);
    });
  }

  test('ссылка «Поделиться» остаётся как есть до перехода по ней', () {
    final link = InstagramUrlParser.parse(
      'https://www.instagram.com/share/reel/BAbc123xyz/?igsh=tracking',
    );

    expect(link?.isShare, isTrue);
    expect(link?.code, isNull);
    expect(link?.url, 'https://www.instagram.com/share/reel/BAbc123xyz/');
  });

  for (final url in [
    'https://www.instagram.com/wasted/',
    'https://www.instagram.com/stories/wasted/3914735636548197258/',
    'https://www.instagram.com/reels/audio/1234567890/',
    'https://www.instagram.com/explore/tags/cats/',
    'https://www.instagram.com.evil.com/reel/$_code/',
    'ftp://www.instagram.com/reel/$_code/',
    'https://www.tiktok.com/@bmw/video/7664657841843719457',
    '',
  ]) {
    test('отклоняет «$url»', () {
      expect(InstagramUrlParser.parse(url), isNull);
    });
  }

  test('сайт видео определяется по ссылке', () {
    expect(
      VideoLinks.sourceOf('https://www.instagram.com/reel/$_code/'),
      VideoSourceModel.instagram,
    );
    expect(
      VideoLinks.sourceOf('https://www.instagram.com/share/p/BAbc123xyz/'),
      VideoSourceModel.instagram,
    );
  });

  group('качества Instagram', () {
    test('готовый файл H.264 раньше DASH того же разрешения, VP9 помечен', () {
      final qualities = InstagramQualities.build(_reelStreams);

      expect(
        qualities.map((quality) => (quality.id, quality.label, quality.size)),
        [('1080', '1080p · VP9', 492039 + 73743), ('720', '720p', 438095)],
      );
    });

    test('DASH-видео качается со звуком, готовый файл — один', () {
      final dash = InstagramQualities.select(_reelStreams, quality: '1080');
      final file = InstagramQualities.select(_reelStreams, quality: '720');

      expect(dash?.video.key, 1654544069172785);
      expect(dash?.audio?.key, 989422917031360);
      expect(file?.video.kind, InstagramStreamKind.file);
      expect(file?.audio, isNull);
    });

    test('после паузы берётся поток прошлой загрузки', () {
      final choice = InstagramQualities.select(
        _reelStreams,
        quality: '720',
        previousVideoKey: 1211135347711936,
      );

      expect(choice?.video.kind, InstagramStreamKind.video);
      expect(choice?.audio?.key, 989422917031360);
    });

    test('файл без размера картинки не становится качеством', () {
      final qualities = InstagramQualities.build([
        _stream(InstagramStreamKind.file, key: 0),
        ..._reelStreams.skip(1),
      ]);

      expect(qualities.map((quality) => quality.label), [
        '1080p · VP9',
        '720p · VP9',
      ]);
      expect(InstagramQualities.select(_reelStreams, quality: '480'), isNull);
    });
  });

  group('заголовок MP4', () {
    test('moov в начале: кодек, картинка и длительность', () {
      final file = progressiveMp4(mdat: [Uint8List(1000)]);
      final seek = Mp4Probe.seek(file, fileLength: file.length);

      expect(seek, isA<Mp4MoovAt>());

      final moov = seek as Mp4MoovAt;
      final info = Mp4Probe.videoOf(
        Uint8List.sublistView(file, moov.offset, moov.offset + moov.size),
      );

      expect(
        info,
        const Mp4VideoInfo(
          codec: 'avc1',
          width: 720,
          height: 1280,
          duration: 10,
        ),
      );
    });

    test('moov после mdat: читать дальше с конца mdat', () {
      final file = progressiveMp4(mdat: [Uint8List(100000)], moovFirst: false);
      final seek = Mp4Probe.seek(
        Uint8List.sublistView(file, 0, 65536),
        fileLength: file.length,
      );

      expect(seek, isA<Mp4ReadFrom>());
      expect(
        Mp4Probe.seek(
          Uint8List.sublistView(file, (seek as Mp4ReadFrom).offset),
          chunkOffset: seek.offset,
          fileLength: file.length,
        ),
        isA<Mp4MoovAt>(),
      );
    });

    test('без moov — Mp4NoMoov', () {
      final file = box('mdat', [Uint8List(100)]);

      expect(Mp4Probe.seek(file, fileLength: file.length), isA<Mp4NoMoov>());
    });
  });
}
