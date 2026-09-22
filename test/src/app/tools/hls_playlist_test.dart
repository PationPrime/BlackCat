import 'package:flutter_test/flutter_test.dart';
import 'package:peeky_cat/src/app/tools/tools.dart';

final _base = Uri.parse('https://cdn.example/hls/abc/index.m3u8?i=1');

void main() {
  test(
    'варианты мастер-плейлиста: качество, кодеки в кавычках, свои ссылки',
    () {
      final variants = HlsPlaylistParser.parseMaster('''
#EXTM3U
#EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=130000,FRAME-RATE=30,CODECS="avc1.42c014, mp4a.40.29",RESOLUTION=80x144
https://cdn-1.example/a/144.mp4.m3u8?i=80x144_130
#EXT-X-STREAM-INF:BANDWIDTH=1406000,RESOLUTION=608x1080
1080.m3u8
''', _base);

      expect(variants, [
        HlsVariant(
          uri: Uri.parse('https://cdn-1.example/a/144.mp4.m3u8?i=80x144_130'),
          bandwidth: 130000,
          width: 80,
          height: 144,
          codecs: 'avc1.42c014, mp4a.40.29',
          frameRate: 30,
        ),
        HlsVariant(
          uri: Uri.parse('https://cdn.example/hls/abc/1080.m3u8'),
          bandwidth: 1406000,
          width: 608,
          height: 1080,
        ),
      ]);
    },
  );

  test(
    'сегменты медиа-плейлиста с длительностью и относительными ссылками',
    () {
      final playlist = HlsPlaylistParser.parseMedia('''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:4
#EXT-X-PLAYLIST-TYPE:VOD
#EXTINF:2.000,
seg.mp4/segment-1-v1-a1.ts
#EXTINF:4.000,
seg.mp4/segment-2-v1-a1.ts
#EXT-X-ENDLIST
''', _base);

      expect(playlist.segments.map((segment) => segment.uri.toString()), [
        'https://cdn.example/hls/abc/seg.mp4/segment-1-v1-a1.ts',
        'https://cdn.example/hls/abc/seg.mp4/segment-2-v1-a1.ts',
      ]);
      expect(playlist.duration, 6);
    },
  );

  for (final (name, line, reason) in [
    (
      'зашифрованные сегменты',
      '#EXT-X-KEY:METHOD=AES-128,URI="key"',
      HlsUnsupportedReason.encrypted,
    ),
    (
      'сегменты fMP4',
      '#EXT-X-MAP:URI="init.mp4"',
      HlsUnsupportedReason.segmentFormat,
    ),
  ]) {
    test('$name не поддерживаются', () {
      expect(
        () => HlsPlaylistParser.parseMedia(
          '#EXTM3U\n$line\n#EXTINF:4,\ns1.ts\n#EXT-X-ENDLIST\n',
          _base,
        ),
        throwsA(
          isA<HlsUnsupportedException>().having(
            (e) => e.reason,
            'reason',
            reason,
          ),
        ),
      );
    });
  }

  test('трансляция без конца плейлиста не поддерживается', () {
    expect(
      () => HlsPlaylistParser.parseMedia('#EXTM3U\n#EXTINF:4,\ns1.ts\n', _base),
      throwsA(
        isA<HlsUnsupportedException>().having(
          (e) => e.reason,
          'reason',
          HlsUnsupportedReason.live,
        ),
      ),
    );
  });

  test('не плейлист — ошибка формата', () {
    expect(
      () => HlsPlaylistParser.parseMaster('<html></html>', _base),
      throwsFormatException,
    );
    expect(
      () => HlsPlaylistParser.parseMedia('#EXTM3U\n#EXT-X-ENDLIST\n', _base),
      throwsFormatException,
    );
  });
}
