import 'package:flutter_test/flutter_test.dart';
import 'package:peeky_cat/src/app/data_sources/data_sources.dart';
import 'package:peeky_cat/src/app/dto/dto.dart';

void main() {
  group('EmbedConfigDto', () {
    test('объединяет все вызовы ytcfg.set и находит номер плеера', () {
      const html =
          '<script>ytcfg.set({"INNERTUBE_CLIENT_VERSION":"2.1","LOGGED_IN":true});'
          'var x = 1; ytcfg.set({"VISITOR_DATA":"abc","INNERTUBE_CONTEXT":{"client":{"clientName":"WEB_EMBEDDED_PLAYER"}}}) ;'
          '</script><script src="/s/player/deadbeef/player_ias.vflset/en_US/base.js"></script>';
      final config = EmbedConfigDto.fromHtml(html)!;

      expect(config.playerId, 'deadbeef');
      expect(config.clientVersion, '2.1');
      expect(config.visitorData, 'abc');
      expect(config.loggedIn, isTrue);
      expect(config.context['client'], {'clientName': 'WEB_EMBEDDED_PLAYER'});
      expect(config.context['thirdParty'], {
        'embedUrl': 'https://www.reddit.com/',
      });
    });

    test('страница без настроек не разбирается', () {
      expect(EmbedConfigDto.fromHtml('<html></html>'), isNull);
    });
  });

  test('signatureTimestamp берётся из кода плеера', () {
    expect(
      RemoteYouTubeDataSourceImpl.signatureTimestampOf(
        'var a={signatureTimestamp:20702,b:1}',
      ),
      20702,
    );
    expect(
      RemoteYouTubeDataSourceImpl.signatureTimestampOf('nothing here'),
      isNull,
    );
  });

  group('PlayerResponseDto', () {
    final response = PlayerResponseDto.fromJson({
      'playabilityStatus': {'status': 'OK'},
      'videoDetails': {
        'title': 'Обзор',
        'author': 'Канал',
        'lengthSeconds': '478',
        'viewCount': '20461',
        'thumbnail': {
          'thumbnails': [
            {'url': 'small.jpg'},
            {'url': 'large.jpg'},
          ],
        },
      },
      'streamingData': {
        'adaptiveFormats': [
          {
            'itag': 137,
            'mimeType': 'video/mp4; codecs="avc1.640028"',
            'url': 'https://g/v?itag=137&n=N137',
            'width': 1920,
            'height': 1080,
            'contentLength': '100',
          },
          {
            'itag': 248,
            'mimeType': 'video/webm; codecs="vp9"',
            'url': 'https://g/v?itag=248',
            'contentLength': '100',
          },
          {
            'itag': 18,
            'mimeType': 'video/mp4; codecs="avc1.42001E, mp4a.40.2"',
          },
          {
            'itag': 134,
            'mimeType': 'video/mp4; codecs="avc1.4d401e"',
            'contentLength': '21',
            'signatureCipher':
                's=ENCRYPTED&sp=sig&url=${Uri.encodeComponent('https://g/v?itag=134&n=N134')}',
          },
        ],
      },
    });

    test('только скачиваемые MP4-потоки, кодеки, размеры и шифр', () {
      expect(response.isPlayable, isTrue);
      expect(response.formats.map((format) => format.itag), [137, 134]);
      expect(response.formats.first.videoCodec, 'avc1.640028');
      expect(response.formats.first.hasAudio, isFalse);
      expect(response.formats.last.signature, 'ENCRYPTED');
      expect(response.formats.last.signatureParam, 'sig');
      expect(response.formats.last.nChallenge, 'N134');
      expect(
        [
          response.title,
          response.author,
          response.lengthSeconds,
          response.viewCount,
          response.thumbnail,
        ],
        ['Обзор', 'Канал', 478, 20461, 'large.jpg'],
      );
    });

    test('resolvedUrl подставляет решения n и подписи', () {
      final url = Uri.parse(
        response.formats.last.resolvedUrl(
          n: {'N134': 'SOLVED'},
          sig: {'ENCRYPTED': 'SIGNED'},
        ),
      );

      expect(url.queryParameters['n'], 'SOLVED');
      expect(url.queryParameters['sig'], 'SIGNED');
      expect(url.queryParameters['itag'], '134');
      expect(
        () => response.formats.first.resolvedUrl(n: const {}, sig: const {}),
        throwsStateError,
      );
    });

    test('отказ YouTube: причина и нужен ли вход', () {
      final loginRequired = PlayerResponseDto.fromJson({
        'playabilityStatus': {
          'status': 'LOGIN_REQUIRED',
          'reason': ' Войдите в аккаунт ',
        },
      });

      expect(loginRequired.isPlayable, isFalse);
      expect(loginRequired.requiresSignIn, isTrue);
      expect(loginRequired.reason, 'Войдите в аккаунт');
    });
  });
}
