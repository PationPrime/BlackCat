import 'package:flutter_test/flutter_test.dart';
import 'package:peeky_cat/src/app/models/models.dart';
import 'package:peeky_cat/src/app/tools/tools.dart';

const _id = '19bfb665a164217084d9a5b4d8a9e734';

void main() {
  test('видео из плейлиста: плейлист отбрасывается', () {
    final link = RuTubeUrlParser.parse(
      'https://rutube.ru/video/$_id/?playlist=346913',
    );

    expect(link?.id, _id);
    expect(link?.isShorts, isFalse);
    expect(link?.url, 'https://rutube.ru/video/$_id/');
  });

  test('шортс остаётся шортсом', () {
    final link = RuTubeUrlParser.parse(
      'https://rutube.ru/shorts/7fe803e5db2951c0a6097232efc4a439/',
    );

    expect(link?.isShorts, isTrue);
    expect(
      link?.url,
      'https://rutube.ru/shorts/7fe803e5db2951c0a6097232efc4a439/',
    );
  });

  test('приватное видео сохраняет ключ доступа', () {
    final link = RuTubeUrlParser.parse(
      'https://rutube.ru/video/private/$_id/?p=AbC-12_x',
    );

    expect(link?.privateKey, 'AbC-12_x');
    expect(link?.url, 'https://rutube.ru/video/private/$_id/?p=AbC-12_x');
  });

  for (final url in [
    'https://rutube.ru/video/$_id',
    'https://m.rutube.ru/video/$_id/',
    'https://www.rutube.ru/video/${_id.toUpperCase()}/',
    'https://rutube.ru/play/embed/$_id',
    '  http://rutube.ru/video/$_id/?t=15  ',
  ]) {
    test('принимает ${url.trim()}', () {
      expect(RuTubeUrlParser.parse(url)?.url, 'https://rutube.ru/video/$_id/');
    });
  }

  for (final url in [
    'https://rutube.ru/channel/12345/',
    'https://rutube.ru/video/not-an-id/',
    'https://rutube.ru.evil.com/video/$_id/',
    'ftp://rutube.ru/video/$_id/',
    'https://www.youtube.com/watch?v=kgA8JPY2lIA',
    '',
  ]) {
    test('отклоняет «$url»', () {
      expect(RuTubeUrlParser.parse(url), isNull);
    });
  }

  test('сайт видео определяется по ссылке', () {
    expect(
      VideoLinks.sourceOf('https://youtu.be/kgA8JPY2lIA'),
      VideoSourceModel.youtube,
    );
    expect(
      VideoLinks.sourceOf('https://rutube.ru/video/$_id/'),
      VideoSourceModel.rutube,
    );
    expect(VideoLinks.sourceOf('https://vk.com/video1_2'), isNull);
  });
}
