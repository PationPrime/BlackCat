import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:black_cat/src/app/api/api.dart';
import 'package:black_cat/src/app/data_sources/data_sources.dart';
import 'package:black_cat/src/app/errors/errors.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/operation_result/operation_result.dart';
import 'package:black_cat/src/app/repositories/repositories.dart';
import 'package:black_cat/src/app/services/services.dart';
import 'package:black_cat/src/app/tools/tools.dart';

import '../../support/dash_stream_builder.dart';
import '../../support/mp4_file_builder.dart';
import '../../support/test_localization.dart';

const _code = 'DZT71H-BJuK';
const _url = 'https://www.instagram.com/reel/$_code/?hl=en';
const _title = '🥲 Instagram Reels are short-form videos';

/// Posts of the server by their code
const _photoCode = 'PHOTO12345';
const _gatedCode = 'GATED12345';
const _carouselCode = 'CAROUSEL12';
const _limitedCode = 'LIMITED123';

const _dashVideo720 = 1211135347711936;
const _dashVideo1080 = 1654544069172785;
const _dashAudio = 989422917031360;

/// Fragmented MP4 video or audio, as Instagram DASH gives it
Uint8List _dashFile(String handler, String data) => dashStream(
  handler: handler,
  timescale: 1000,
  fragments: [
    (0, [(data, 5000, true, 0), (data, 5000, false, 0)]),
  ],
);

/// Instagram stand-in: post pages that carry the post only for a browser
/// that opens them, a ready file and DASH files served in parts
final class _InstagramServer {
  final requests = <String>[];
  final files = <String, Uint8List>{
    '/file/reel.mp4': progressiveMp4(
      mdat: [
        for (var i = 1; i <= 3; i++) Uint8List(40000)..fillRange(0, 40000, i),
      ],
    ),
    '/dash/$_dashVideo720.mp4': _dashFile('vide', 'video-720'),
    '/dash/$_dashVideo1080.mp4': _dashFile('vide', 'video-1080'),
    '/dash/$_dashAudio.m4a': _dashFile('soun', 'audio'),
  };

  /// Files answer 403 until the page was asked this many times: the links
  /// of the earlier pages have expired
  var filesForbiddenUntilPages = 0;

  late final HttpServer _server;

  String get origin => 'http://${_server.address.host}:${_server.port}';

  int get pageRequests => requests
      .where((path) => path.startsWith('/reel/') || path.startsWith('/p/'))
      .length;

  List<String> fileRequests(String path) =>
      requests.where((request) => request == path).toList();

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    final response = request.response;

    requests.add(path);

    try {
      if (RegExp(r'^/(?:reel|p)/([\w-]+)/$').firstMatch(path)
          case final match?) {
        if (match.group(1) == _limitedCode) {
          response
            ..statusCode = HttpStatus.found
            ..headers.set('location', '/accounts/login/?next=$path');

          return;
        }

        response.headers.contentType = ContentType.html;

        /// Without the browser headers the page is an error page
        response.write(
          request.headers.value('sec-fetch-mode') == 'navigate'
              ? _page(match.group(1)!)
              : _errorPage,
        );
      } else if (path.startsWith('/accounts/login')) {
        response.headers.contentType = ContentType.html;
        response.write('<html>login</html>');
      } else if (files[path] case final bytes?) {
        _file(request, bytes);
      } else {
        response.statusCode = 404;
      }
    } finally {
      await response.close();
    }
  }

  void _file(HttpRequest request, Uint8List bytes) {
    final response = request.response;

    if (pageRequests < filesForbiddenUntilPages) {
      response.statusCode = 403;

      return;
    }

    final range = RegExp(
      r'^bytes=(\d+)-(\d*)$',
    ).firstMatch(request.headers.value('range') ?? '');

    if (range == null) {
      response.contentLength = bytes.length;
      response.add(bytes);

      return;
    }

    final start = int.parse(range.group(1)!);
    final requestedEnd = range.group(2)!.isEmpty
        ? bytes.length - 1
        : int.parse(range.group(2)!);
    final end = requestedEnd < bytes.length ? requestedEnd : bytes.length - 1;

    response
      ..statusCode = 206
      ..contentLength = end - start + 1;
    response.headers.set('content-range', 'bytes $start-$end/${bytes.length}');
    response.add(bytes.sublist(start, end + 1));
  }

  static const _errorPage =
      '<html><script type="application/json" data-sjs>'
      '{"require":[["PolarisRouter",{"pageID":"httpErrorPage"}]]}'
      '</script></html>';

  String _manifest() {
    String representation(
      int id,
      String mimeType,
      String codecs,
      String path, {
      int? width,
      int? height,
      required int bandwidth,
    }) =>
        '<Representation id="$id${mimeType.startsWith('audio') ? 'a' : 'v'}" '
        'bandwidth="$bandwidth" codecs="$codecs" mimeType="$mimeType" '
        '${width == null ? '' : 'width="$width" height="$height" '}'
        'FBContentLength="${files[path]!.length}">'
        '<BaseURL>$origin$path?oh=1&amp;oe=2</BaseURL>'
        '<SegmentBase indexRange="0-1"><Initialization range="0-1"/>'
        '</SegmentBase></Representation>';

    return '<?xml version="1.0"?><MPD mediaPresentationDuration="PT10.0S">'
        '<Period><AdaptationSet>'
        '${representation(_dashVideo720, 'video/mp4', 'vp09.00.31.08', '/dash/$_dashVideo720.mp4', width: 720, height: 1280, bandwidth: 202838)}'
        '${representation(_dashVideo1080, 'video/mp4', 'vp09.00.40.08', '/dash/$_dashVideo1080.mp4', width: 1080, height: 1920, bandwidth: 394947)}'
        '</AdaptationSet><AdaptationSet>'
        '${representation(_dashAudio, 'audio/mp4', 'mp4a.40.5', '/dash/$_dashAudio.m4a', bandwidth: 58361)}'
        '</AdaptationSet></Period></MPD>';
  }

  Map<String, Object?> get _video => {
    'media_type': 2,

    /// Its versions are the same file
    'video_versions': [
      for (final type in [101, 102, 103])
        {'type': type, 'url': '$origin/file/reel.mp4'},
    ],
    'video_dash_manifest': _manifest(),
    'image_versions2': {
      'candidates': [
        {'url': '$origin/cover.jpg', 'width': 640, 'height': 1136},
      ],
    },
  };

  String _page(String code) {
    final post = switch (code) {
      _gatedCode => null,
      _photoCode => {
        'media_type': 1,
        'image_versions2': {'candidates': <Object>[]},
      },
      _carouselCode => {
        'media_type': 8,
        'carousel_media': [
          {'media_type': 1},
          _video,
        ],
      },
      _ => _video,
    };
    final media = {
      'code': code,
      'if_not_gated_logged_out': post == null
          ? null
          : {
              ...post,
              'code': code,
              'product_type': 'clips',
              'caption': {
                'text': '🥲\n\nInstagram Reels are  short-form videos',
              },
              'user': {'username': 'wasted', 'full_name': 'WASTED'},
            },
    };

    /// The page keeps the post deep in its prefetched requests
    final data = {
      'require': [
        [
          'ScheduledServerJS',
          'handle',
          null,
          [
            {
              '__bbox': {
                'require': [
                  [
                    'RelayPrefetchedStreamCache',
                    'next',
                    <Object>[],
                    [
                      'adp_PolarisPostRootQuery',
                      {
                        '__bbox': {
                          'result': {
                            'data': {'xig_polaris_media': media},
                          },
                        },
                      },
                    ],
                  ],
                ],
              },
            },
          ],
        ],
      ],
    };

    return '<html><head></head><body>'
        '<script type="application/json" data-sjs>{"require":[]}</script>'
        '<script type="application/json" data-content-len="1" data-sjs>'
        '${jsonEncode(data).replaceAll('/', r'\/')}'
        '</script></body></html>';
  }
}

/// Downloads and app folders are in the test temp folder
class _TestFileSystemService extends FileSystemServiceImpl {
  final Directory root;

  _TestFileSystemService(this.root);

  @override
  Future<String> localAppFolder(String name) async => p.join(root.path, name);

  @override
  Future<String> supportFolder() async => p.join(root.path, 'support');

  @override
  Future<String> defaultDownloadsFolder() async =>
      p.join(root.path, 'Downloads');
}

/// yt-dlp stand-in: prints the info of the post and "downloads" the chosen
/// format by writing its bytes where yt-dlp would
final class _FakeYtDlpService implements YtDlpService {
  final _InstagramServer server;
  final downloads = <String>[];

  _FakeYtDlpService(this.server);

  @override
  bool get isSupported => true;

  @override
  Future<YtDlpSetupModel> setup({bool refresh = false}) =>
      throw UnimplementedError();

  String get _info => jsonEncode({
    'id': _code,
    'title': 'Video by wasted',
    'description': '🥲\n\nInstagram Reels are  short-form videos',
    'channel': 'wasted',
    'uploader': 'WASTED',
    'thumbnail': '${server.origin}/cover.jpg',
    'formats': [
      {
        'format_id': 'dash-${_dashAudio}a',
        'url': '${server.origin}/dash/$_dashAudio.m4a',
        'vcodec': 'none',
        'acodec': 'mp4a.40.5',
        'tbr': 58.361,
        'container': 'm4a_dash',
      },
      for (final id in ['1', '2', '3'])
        {
          'format_id': id,
          'url': '${server.origin}/file/reel.mp4',
          'ext': 'mp4',
        },
      for (final (id, width, height, tbr) in [
        (_dashVideo720, 720, 1280, 202.838),
        (_dashVideo1080, 1080, 1920, 394.947),
      ])
        {
          'format_id': 'dash-${id}v',
          'url': '${server.origin}/dash/$id.mp4',
          'vcodec': 'vp09.00.40.08.00.01.01.01.00',
          'acodec': 'none',
          'width': width,
          'height': height,
          'tbr': tbr,
          'container': 'mp4_dash',
        },
    ],
  });

  @override
  Future<YtDlpRunResult> run(
    List<String> arguments, {
    ValueChanged<String>? onLine,
    DownloadCancellation? cancellation,
  }) async {
    if (arguments.contains('--dump-single-json')) {
      return YtDlpRunResult(exitCode: 0, stdout: _info);
    }

    final format = arguments[arguments.indexOf('--format') + 1];
    final output = arguments[arguments.indexOf('--output') + 1];

    downloads.add(format);

    final path = switch (format) {
      'dash-${_dashAudio}a' => '/dash/$_dashAudio.m4a',
      final id when id.startsWith('dash-') =>
        '/dash/${id.substring(5, id.length - 1)}.mp4',
      _ => '/file/reel.mp4',
    };

    await File(output).writeAsBytes(server.files[path]!);

    return const YtDlpRunResult(exitCode: 0);
  }
}

void main() {
  late Directory root;
  late _InstagramServer server;
  late _TestFileSystemService fileSystemService;
  late RemoteInstagramDataSource dataSource;
  late InstagramVideoRepository repository;

  setUpAll(loadTestTranslations);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('instagram-repository');
    server = _InstagramServer();
    await server.start();
    fileSystemService = _TestFileSystemService(root);
    dataSource = RemoteInstagramDataSourceImpl(
      apiProvider: ApiProvider(),
      origin: server.origin,
    );
    repository = InstagramVideoRepository(
      remoteInstagramDataSource: dataSource,
      mediaMuxerService: const Mp4MediaMuxerServiceImpl(),
      fileSystemService: fileSystemService,
    );
  });

  tearDown(() async {
    await server.close();
    await root.delete(recursive: true);
  });

  Future<OperationResult<DownloadedFileModel>> download(
    VideoRepositoryInterface repository, {
    required String quality,
    String taskId = 'task-1',
    List<DownloadStreamModel> streams = const [],
    void Function(List<DownloadStreamModel> streams)? onStreamsSelected,
  }) => repository.downloadVideo(
    taskId: taskId,
    url: _url,
    quality: quality,
    streams: streams,
    onStreamsSelected: onStreamsSelected,
  );

  /// Tracks of a muxed MP4
  Future<List<String>> tracksOf(String path) async {
    final boxes = topLevel(await File(path).readAsBytes());

    expect(boxes.map((box) => box.type), ['ftyp', 'moov', 'mdat']);

    return [
      for (final trak in boxes[1].all('trak'))
        String.fromCharCodes(trak.child('mdia').child('hdlr').bytes, 16, 20),
    ];
  }

  test(
    'рилс: подпись в заголовке, готовый файл 720p и DASH 1080p в VP9',
    () async {
      final result = await repository.getVideoInfo(_url);

      expect(result.failure, isNull, reason: result.failure?.message);

      final video = result.requireData;

      expect(video.id, _code);
      expect(video.title, _title);
      expect(video.channel, 'WASTED');
      expect(video.duration, 10);
      expect(video.url, 'https://www.instagram.com/reel/$_code/');
      expect(video.thumbnail, '${server.origin}/cover.jpg');
      expect(
        video.qualities.map(
          (quality) => (quality.id, quality.label, quality.size),
        ),
        [
          (
            '1080',
            '1080p · VP9',
            server.files['/dash/$_dashVideo1080.mp4']!.length +
                server.files['/dash/$_dashAudio.m4a']!.length,
          ),
          ('720', '720p', server.files['/file/reel.mp4']!.length),
        ],
      );

      /// The ready file tells its picture by its first bytes
      expect(server.requests, contains('/file/reel.mp4'));
      expect(server.requests.first, '/reel/$_code/');
    },
  );

  test('готовый файл скачивается как есть', () async {
    final selected = <DownloadStreamModel>[];
    final result = await download(
      repository,
      quality: '720',
      onStreamsSelected: selected.addAll,
    );

    expect(result.failure, isNull, reason: result.failure?.message);
    expect(
      result.requireData.path,
      p.join(root.path, 'Downloads', '$_title.mp4'),
    );
    expect(
      await File(result.requireData.path).readAsBytes(),
      server.files['/file/reel.mp4'],
    );
    expect(selected.single.itag, server.files['/file/reel.mp4']!.length);
    expect(server.fileRequests('/dash/$_dashVideo1080.mp4'), isEmpty);
    expect(
      Directory(
        p.join(root.path, 'Unfinished downloads', 'task-1'),
      ).existsSync(),
      isFalse,
    );
  });

  test('DASH-видео и звук скачиваются и собираются в один MP4', () async {
    final selected = <DownloadStreamModel>[];
    final result = await download(
      repository,
      quality: '1080',
      onStreamsSelected: selected.addAll,
    );

    expect(result.failure, isNull, reason: result.failure?.message);
    expect(selected.map((stream) => (stream.role, stream.itag)), [
      (DownloadStreamRole.video, _dashVideo1080),
      (DownloadStreamRole.audio, _dashAudio),
    ]);
    expect(await tracksOf(result.requireData.path), ['vide', 'soun']);
  });

  test(
    'ссылки устарели (403): страница берётся заново, и загрузка продолжается',
    () async {
      server.filesForbiddenUntilPages = 2;

      final result = await download(repository, quality: '1080');

      expect(result.failure, isNull, reason: result.failure?.message);
      expect(server.pageRequests, 2);
    },
  );

  test('продолжение после паузы берёт тот же поток, что и раньше', () async {
    final result = await download(
      repository,
      quality: '720',
      streams: const [
        DownloadStreamModel(
          role: DownloadStreamRole.video,
          itag: _dashVideo720,
          contentLength: 1000,
        ),
      ],
    );

    expect(result.failure, isNull, reason: result.failure?.message);
    expect(server.fileRequests('/dash/$_dashVideo720.mp4'), isNotEmpty);
    expect(await tracksOf(result.requireData.path), ['vide', 'soun']);
  });

  test('в карусели берётся первое видео', () async {
    final result = await repository.getVideoInfo(
      'https://www.instagram.com/p/$_carouselCode/',
    );

    expect(result.failure, isNull, reason: result.failure?.message);
    expect(result.requireData.qualities, hasLength(2));
    expect(
      result.requireData.url,
      'https://www.instagram.com/p/$_carouselCode/',
    );
  });

  for (final (name, code, error) in [
    ('пост только с фото', _photoCode, const VideoErrorCodes().instagramPhoto),
    (
      'пост только для вошедших',
      _gatedCode,
      const VideoErrorCodes().instagramUnavailable,
    ),
    (
      'Instagram отправил на страницу входа',
      _limitedCode,
      const VideoErrorCodes().instagramRateLimited,
    ),
  ]) {
    test('$name — своя ошибка', () async {
      final result = await repository.getVideoInfo(
        'https://www.instagram.com/p/$code/',
      );

      expect(result.failure?.code, error);
    });
  }

  test('страница без поста — видео недоступно', () async {
    final page = await ApiProvider().instagram.dio.get<String>(
      '${server.origin}/reel/$_code/',
    );

    expect(
      () => RemoteInstagramDataSourceImpl.videoOf(page.data!),
      throwsA(
        isA<VideoException>().having(
          (error) => error.code,
          'code',
          const VideoErrorCodes().instagramUnavailable,
        ),
      ),
    );
  });

  test('ссылка не на Instagram — своя ошибка', () async {
    final result = await repository.getVideoInfo(
      'https://youtu.be/kgA8JPY2lIA',
    );

    expect(result.failure?.message, 'Это не ссылка на видео Instagram.');
  });

  group('yt-dlp', () {
    late _FakeYtDlpService ytDlpService;
    late InstagramYtDlpVideoRepository ytDlpRepository;

    setUp(() {
      ytDlpService = _FakeYtDlpService(server);
      ytDlpRepository = InstagramYtDlpVideoRepository(
        ytDlpService: ytDlpService,
        remoteInstagramDataSource: dataSource,
        mediaMuxerService: const Mp4MediaMuxerServiceImpl(),
        fileSystemService: fileSystemService,
      );
    });

    test('качества те же, что у встроенного загрузчика: картинка готового '
        'файла — из его заголовка', () async {
      final result = await ytDlpRepository.getVideoInfo(_url);

      expect(result.failure, isNull, reason: result.failure?.message);
      expect(result.requireData.title, _title);
      expect(result.requireData.channel, 'WASTED');
      expect(result.requireData.duration, 10);
      expect(result.requireData.qualities.map((quality) => quality.label), [
        '1080p · VP9',
        '720p',
      ]);
    });

    test('готовый файл — один формат yt-dlp', () async {
      final result = await download(ytDlpRepository, quality: '720');

      expect(result.failure, isNull, reason: result.failure?.message);
      expect(ytDlpService.downloads, ['1']);
      expect(
        await File(result.requireData.path).readAsBytes(),
        server.files['/file/reel.mp4'],
      );
    });

    test('DASH — видео и звук отдельно, затем сборка в MP4', () async {
      final result = await download(ytDlpRepository, quality: '1080');

      expect(result.failure, isNull, reason: result.failure?.message);
      expect(ytDlpService.downloads, [
        'dash-${_dashVideo1080}v',
        'dash-${_dashAudio}a',
      ]);
      expect(await tracksOf(result.requireData.path), ['vide', 'soun']);
    });
  });

  test('ссылки всех сайтов уходят в репозиторий своего сайта', () async {
    final tiktok = _RecordingRepository();
    final instagram = _RecordingRepository();
    final router = SourceVideoRepository({
      VideoSourceModel.youtube: _RecordingRepository(),
      VideoSourceModel.rutube: _RecordingRepository(),
      VideoSourceModel.tiktok: tiktok,
      VideoSourceModel.instagram: instagram,
    });

    await router.getVideoInfo(
      'https://www.tiktok.com/@bmw/video/7664657841843719457',
    );
    await router.getVideoInfo(_url);
    await router.getVideoInfo('https://www.instagram.com/share/reel/BAbc123/');

    final unsupported = await router.getVideoInfo('https://vk.com/video1_2');

    expect(tiktok.urls, hasLength(1));
    expect(instagram.urls, [
      _url,
      'https://www.instagram.com/share/reel/BAbc123/',
    ]);
    expect(
      unsupported.failure?.message,
      'Это не ссылка на видео YouTube, RuTube, TikTok, Instagram или X.',
    );
  });
}

/// Remembers the links it was asked about
final class _RecordingRepository implements VideoRepositoryInterface {
  final urls = <String>[];

  @override
  ErrorHandler<VideoErrorCodes> get errorHandler => const VideoErrorHandler();

  @override
  Future<OperationResult<VideoInfoModel>> getVideoInfo(String url) async {
    urls.add(url);

    return ok(
      VideoInfoModel(id: url, title: url, url: url, qualities: const []),
    );
  }

  @override
  Future<OperationResult<DownloadedFileModel>> downloadVideo({
    required String taskId,
    required String url,
    required String quality,
    List<DownloadStreamModel> streams = const [],
    String? destinationDirectory,
    DownloadCancellation? cancellation,
    void Function(List<DownloadStreamModel> streams)? onStreamsSelected,
    void Function(DownloadProgressModel progress)? onProgress,
  }) async => throw UnimplementedError();
}
