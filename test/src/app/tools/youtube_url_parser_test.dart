import 'package:flutter_test/flutter_test.dart';
import 'package:peeky_cat/src/app/tools/tools.dart';

const _targetUrl = 'https://www.youtube.com/watch?v=kgA8JPY2lIA';

void main() {
  test('отбрасывает метку отслеживания pp', () {
    final link = YouTubeUrlParser.parse(
      'https://www.youtube.com/watch?v=kgA8JPY2lIA&pp=ugUEEgJydQ%3D%3D',
    );

    expect(link?.id, 'kgA8JPY2lIA');
    expect(link?.url, _targetUrl);
  });

  for (final link in [
    'https://youtu.be/kgA8JPY2lIA?si=abc',
    'https://m.youtube.com/watch?v=kgA8JPY2lIA',
    'https://www.youtube.com/watch?list=PL123&v=kgA8JPY2lIA&index=2',
    'https://www.youtube.com/shorts/kgA8JPY2lIA',
    'https://www.youtube.com/embed/kgA8JPY2lIA?start=10',
    'https://www.youtube-nocookie.com/embed/kgA8JPY2lIA',
    'https://www.youtube.com/live/kgA8JPY2lIA',
    'https://WWW.YouTube.com/watch?v=kgA8JPY2lIA',
    '  http://youtube.com/watch?v=kgA8JPY2lIA  ',
  ]) {
    test('принимает ${link.trim()}', () {
      expect(YouTubeUrlParser.parse(link)?.url, _targetUrl);
    });
  }

  for (final link in [
    '',
    null,
    'kgA8JPY2lIA',
    'https://example.com/watch?v=kgA8JPY2lIA',
    'https://www.youtube.com.evil.com/watch?v=kgA8JPY2lIA',
    'https://www.youtube.com/watch?v=short',
    'https://www.youtube.com/@2shell',
    'https://www.youtube.com/playlist?list=PL123',
    'https://www.youtube.com/watch?v=%zz',
    'javascript:alert(1)',
  ]) {
    test('отклоняет $link', () {
      expect(YouTubeUrlParser.parse(link), isNull);
    });
  }
}
