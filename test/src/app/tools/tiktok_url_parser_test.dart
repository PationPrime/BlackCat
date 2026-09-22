import 'package:flutter_test/flutter_test.dart';
import 'package:peeky_cat/src/app/dto/dto.dart';
import 'package:peeky_cat/src/app/models/models.dart';
import 'package:peeky_cat/src/app/tools/tools.dart';

const _id = '7664657841843719457';

TikTokFormatDto _format(
  int bitrate, {
  String codec = 'h264',
  int width = 576,
  int height = 1024,
}) => TikTokFormatDto(
  urls: ['https://cdn/$bitrate.mp4'],
  bitrate: bitrate,
  codec: codec,
  width: width,
  height: height,
  size: bitrate ~/ 8 * 7,
);

void main() {
  test('ссылка из браузера: параметры отбрасываются, автор остаётся', () {
    final link = TikTokUrlParser.parse(
      'https://www.tiktok.com/@bmw/video/$_id?is_from_webapp=1&sender_device=pc',
    );

    expect(link?.id, _id);
    expect(link?.author, 'bmw');
    expect(link?.isShort, isFalse);
    expect(link?.isPhoto, isFalse);
    expect(link?.url, 'https://www.tiktok.com/@bmw/video/$_id');
  });

  for (final url in [
    'https://tiktok.com/@_/video/$_id',
    'https://m.tiktok.com/v/$_id.html',
    'https://www.tiktok.com/embed/v2/$_id',
    'https://www.tiktok.com/player/v1/$_id?autoplay=1',
    '  http://www.tiktok.com/@/video/$_id/  ',
  ]) {
    test('без автора открывается по id: ${url.trim()}', () {
      expect(
        TikTokUrlParser.parse(url)?.url,
        'https://www.tiktok.com/@_/video/$_id',
      );
    });
  }

  for (final (url, short) in [
    (
      'https://vm.tiktok.com/ZMabc123/?utm=share',
      'https://vm.tiktok.com/ZMabc123/',
    ),
    ('https://vt.tiktok.com/ZSxyz-9/', 'https://vt.tiktok.com/ZSxyz-9/'),
    ('https://www.tiktok.com/t/ZTR7abc/', 'https://www.tiktok.com/t/ZTR7abc/'),
  ]) {
    test('короткая ссылка остаётся как есть: $short', () {
      final link = TikTokUrlParser.parse(url);

      expect(link?.isShort, isTrue);
      expect(link?.id, isNull);
      expect(link?.url, short);
    });
  }

  test('фото-пост узнаётся по ссылке', () {
    final link = TikTokUrlParser.parse(
      'https://www.tiktok.com/@bmw/photo/$_id',
    );

    expect(link?.isPhoto, isTrue);
    expect(link?.url, 'https://www.tiktok.com/@bmw/photo/$_id');
  });

  for (final url in [
    'https://www.tiktok.com/@bmw',
    'https://www.tiktok.com/@bmw/video/not-an-id',
    'https://www.tiktok.com/v/123.html',
    'https://www.tiktok.com.evil.com/@bmw/video/$_id',
    'https://vm.tiktok.com/',
    'ftp://www.tiktok.com/@bmw/video/$_id',
    'https://rutube.ru/video/19bfb665a164217084d9a5b4d8a9e734/',
    '',
  ]) {
    test('отклоняет «$url»', () {
      expect(TikTokUrlParser.parse(url), isNull);
    });
  }

  test('сайт видео определяется по ссылке', () {
    expect(
      VideoLinks.sourceOf('https://www.tiktok.com/@bmw/video/$_id'),
      VideoSourceModel.tiktok,
    );
    expect(
      VideoLinks.sourceOf('https://vm.tiktok.com/ZMabc123/'),
      VideoSourceModel.tiktok,
    );
  });

  group('качества TikTok', () {
    test('одно качество на разрешение, H.265 помечено', () {
      final qualities = TikTokQualities.build([
        _format(593369),
        _format(1059315),
        _format(512954, codec: 'h265_hvc1'),
        _format(1048425, codec: 'bytevc1', width: 1080, height: 1920),
      ]);

      expect(qualities.map((quality) => (quality.id, quality.label)), [
        ('1080', '1080p · H.265'),
        ('576', '576p'),
      ]);
      expect(qualities.last.size, 1059315 ~/ 8 * 7);
    });

    test('H.264 выбирается раньше H.265 того же разрешения', () {
      final format = TikTokQualities.select([
        _format(2000000, codec: 'h265_hvc1'),
        _format(593369),
      ], quality: '576');

      expect(format?.bitrate, 593369);
    });

    test('после паузы берётся файл прошлой загрузки', () {
      final format = TikTokQualities.select(
        [_format(593369), _format(1059315)],
        quality: '576',
        previousBitrate: 593369,
      );

      expect(format?.bitrate, 593369);
    });

    test('нет такого качества — null', () {
      expect(
        TikTokQualities.select([_format(593369)], quality: '1080'),
        isNull,
      );
      expect(
        TikTokQualities.select([
          _format(593369),
        ], quality: QualityModel.audioId),
        isNull,
      );
    });
  });
}
