import 'package:flutter_test/flutter_test.dart';
import 'package:black_cat/src/app/data_sources/data_sources.dart';
import 'package:black_cat/src/app/dto/dto.dart';
import 'package:black_cat/src/app/errors/errors.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/tools/tools.dart';

const _id = '2102042791807263094';

Map<String, Object?> _video(String name, {String type = 'video'}) => {
  'type': type,
  'media_url_https': 'https://pbs.twimg.com/media/$name.jpg',
  'original_info': {'width': 1280, 'height': 720},
  'video_info': {
    'duration_millis': 6373,
    'variants': [
      {
        'content_type': 'application/x-mpegURL',
        'url': 'https://video.twimg.com/amplify_video/1/pl/$name.m3u8',
      },
      {
        'content_type': 'video/mp4',
        'bitrate': 832000,
        'url':
            'https://video.twimg.com/amplify_video/1/vid/avc1/640x360/$name.mp4',
      },
      {
        'content_type': 'video/mp4',
        'bitrate': 2176000,
        'url':
            'https://video.twimg.com/amplify_video/1/vid/avc1/1280x720/$name.mp4?tag=16',
      },
    ],
  },
};

const _photo = {
  'type': 'photo',
  'media_url_https': 'https://pbs.twimg.com/media/photo.jpg',
};

Map<String, Object?> _post({
  List<Object?> media = const [],
  Map<String, Object?>? quoted,
}) => {
  '__typename': 'Tweet',
  'id_str': _id,
  'text':
      'Returning to work &amp; playing #WolverinePS5.\n https://t.co/kHTZLnZcYf',
  'user': {'name': 'PlayStation', 'screen_name': 'PlayStation'},
  'mediaDetails': media,
  'quoted_tweet': ?quoted,
};

void main() {
  test('ссылка на видео поста: номер медиа сохраняется', () {
    final link = XUrlParser.parse(
      'https://x.com/PlayStation/status/$_id/video/1?s=20',
    );

    expect(link?.id, _id);
    expect(link?.author, 'PlayStation');
    expect(link?.mediaIndex, 1);
    expect(link?.url, 'https://x.com/PlayStation/status/$_id/video/1');
  });

  for (final (url, expected) in [
    (
      'https://twitter.com/PlayStation/status/$_id',
      'https://x.com/PlayStation/status/$_id',
    ),
    (
      'https://mobile.twitter.com/PlayStation/statuses/$_id/',
      'https://x.com/PlayStation/status/$_id',
    ),
    ('https://x.com/i/status/$_id', 'https://x.com/i/status/$_id'),
    ('https://x.com/i/web/status/$_id', 'https://x.com/i/status/$_id'),
    (
      '  http://www.x.com/sony/status/$_id/photo/2  ',
      'https://x.com/sony/status/$_id/video/2',
    ),
  ]) {
    test('принимает ${url.trim()}', () {
      expect(XUrlParser.parse(url)?.url, expected);
    });
  }

  for (final url in [
    'https://x.com/PlayStation',
    'https://x.com/search?q=cats',
    'https://x.com/PlayStation/status/not-an-id',
    'https://x.com/PlayStation/status/$_id/video/0',
    'https://x.com.evil.com/PlayStation/status/$_id',
    'ftp://x.com/PlayStation/status/$_id',
    'https://www.instagram.com/reel/DZT71H-BJuK/',
    '',
  ]) {
    test('отклоняет «$url»', () {
      expect(XUrlParser.parse(url), isNull);
    });
  }

  test('сайт видео определяется по ссылке', () {
    expect(
      VideoLinks.sourceOf('https://x.com/PlayStation/status/$_id'),
      VideoSourceModel.x,
    );
    expect(
      VideoLinks.sourceOf('https://twitter.com/i/status/$_id'),
      VideoSourceModel.x,
    );
  });

  test('токен API для встраивания считается как в скрипте X', () {
    /// The same tokens yt-dlp computes
    expect(RemoteXDataSourceImpl.syndicationToken(_id), '53frfsuc4o');
    expect(RemoteXDataSourceImpl.syndicationToken('20'), '6dq1a2xwd93');
    expect(
      RemoteXDataSourceImpl.syndicationToken('1349365911120195585'),
      '39r5ot7e5fr',
    );
    expect(
      RemoteXDataSourceImpl.syndicationToken('560070183650213889'),
      '1cvig1cbolx',
    );
  });

  group('качества X', () {
    test('картинка и кодек — из ссылки на файл', () {
      const url =
          'https://video.twimg.com/amplify_video/1/vid/avc1/1920x1080/a.mp4?tag=16';

      expect(XQualities.sizeOfUrl(url), (width: 1920, height: 1080));
      expect(XQualities.codecOfUrl(url), 'avc1');
      expect(
        XQualities.codecOfUrl('https://video.twimg.com/tweet_video/a.mp4'),
        isNull,
      );
    });

    test('одно качество на разрешение, не H.264 помечено', () {
      final qualities = XQualities.build(const [
        XFormatDto(
          url: 'a',
          bitrate: 832000,
          width: 640,
          height: 360,
          codec: 'avc1',
          size: 100,
        ),
        XFormatDto(
          url: 'b',
          bitrate: 950000,
          width: 640,
          height: 360,
          codec: 'avc1',
          size: 200,
        ),
        XFormatDto(
          url: 'c',
          bitrate: 5000000,
          width: 1920,
          height: 1080,
          codec: 'hevc',
          size: 300,
        ),
      ]);

      expect(
        qualities.map((quality) => (quality.id, quality.label, quality.size)),
        [('1080', '1080p · H.265', 300), ('360', '360p', 200)],
      );
    });
  });

  group('ответ API для встраивания', () {
    test('текст без коротких ссылок, файлы MP4 без HLS', () {
      final video = RemoteXDataSourceImpl.videoOf(
        _post(media: [_video('first')]),
        link: const XPostLink(_id),
      );

      expect(video.title, 'Returning to work & playing #WolverinePS5.');
      expect(video.authorName, 'PlayStation');
      expect(video.durationSeconds, 6.373);
      expect(video.thumbnail, 'https://pbs.twimg.com/media/first.jpg');
      expect(video.url, 'https://x.com/PlayStation/status/$_id');
      expect(video.formats.map((format) => (format.height, format.bitrate)), [
        (360, 832000),
        (720, 2176000),
      ]);
    });

    test('номер медиа из ссылки выбирает видео поста', () {
      final post = _post(media: [_photo, _video('first'), _video('second')]);

      final second = RemoteXDataSourceImpl.videoOf(
        post,
        link: const XPostLink(_id, mediaIndex: 3),
      );
      final first = RemoteXDataSourceImpl.videoOf(
        post,
        link: const XPostLink(_id),
      );

      expect(second.thumbnail, contains('second'));
      expect(second.title, endsWith(' #2'));
      expect(first.thumbnail, contains('first'));
      expect(
        () => RemoteXDataSourceImpl.videoOf(
          post,
          link: const XPostLink(_id, mediaIndex: 1),
        ),
        throwsA(
          isA<VideoException>().having(
            (error) => error.code,
            'code',
            const VideoErrorCodes().xNoVideo,
          ),
        ),
      );
    });

    test('видео процитированного поста, GIF — без картинки в ссылке', () {
      final quoted = RemoteXDataSourceImpl.videoOf(
        _post(quoted: _post(media: [_video('quoted')])),
        link: const XPostLink(_id),
      );
      final gif = RemoteXDataSourceImpl.videoOf(
        _post(
          media: [
            {
              'type': 'animated_gif',
              'original_info': {'width': 480, 'height': 270},
              'video_info': {
                'variants': [
                  {
                    'content_type': 'video/mp4',
                    'bitrate': 0,
                    'url': 'https://video.twimg.com/tweet_video/gif.mp4',
                  },
                ],
              },
            },
          ],
        ),
        link: const XPostLink(_id),
      );

      expect(quoted.thumbnail, contains('quoted'));
      expect(gif.formats.single.height, 270);
      expect(XQualities.build(gif.formats).single.label, '270p');
    });

    for (final (name, json, code) in [
      (
        'удалённый пост',
        const {'__typename': 'TweetTombstone'},
        const VideoErrorCodes().xUnavailable,
      ),
      (
        'пост без видео',
        _post(media: [_photo]),
        const VideoErrorCodes().xNoVideo,
      ),
      (
        'видео недоступно',
        _post(
          media: [
            {
              ..._video('blocked'),
              'ext_media_availability': {'status': 'Unavailable'},
            },
          ],
        ),
        const VideoErrorCodes().xUnavailable,
      ),
    ]) {
      test('$name — своя ошибка', () {
        expect(
          () => RemoteXDataSourceImpl.videoOf(json, link: const XPostLink(_id)),
          throwsA(
            isA<VideoException>().having((error) => error.code, 'code', code),
          ),
        );
      });
    }
  });
}
