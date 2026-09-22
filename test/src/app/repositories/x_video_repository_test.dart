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

import '../../support/test_localization.dart';

const _id = '2102042791807263094';
const _photoId = '2102042791807263001';
const _url = 'https://x.com/PlayStation/status/$_id/video/1';
const _title = 'Returning to work & playing #WolverinePS5.';

/// Files of the post: bitrate, picture and length
const _files = [
  (bitrate: 256000, width: 480, height: 270, size: 90000),
  (bitrate: 832000, width: 640, height: 360, size: 150000),
  (bitrate: 2176000, width: 1280, height: 720, size: 240000),
];

Uint8List _bytesOf(int bitrate, int size) =>
    Uint8List.fromList([for (var i = 0; i < size; i++) (i + bitrate) % 251]);

String _pathOf(({int bitrate, int width, int height, int size}) file) =>
    '/amplify_video/1/vid/avc1/${file.width}x${file.height}/${file.bitrate}.mp4';

/// X stand-in: the embed API and the video files, served in parts
final class _XServer {
  final requests = <String>[];
  final tokens = <String>[];

  /// Files answer 403 until the post was asked this many times
  var filesForbiddenUntilPosts = 0;

  late final HttpServer _server;

  String get origin => 'http://${_server.address.host}:${_server.port}';

  int get postRequests =>
      requests.where((path) => path == '/tweet-result').length;

  /// Whole-file requests: a size check asks for one byte only
  List<String> downloads(int bitrate) =>
      requests.where((path) => path.endsWith('/$bitrate.mp4.full')).toList();

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
      if (path == '/tweet-result') {
        final id = request.uri.queryParameters['id'];

        tokens.add(request.uri.queryParameters['token'] ?? '');

        if (_post(id) case final post?) {
          response.headers.contentType = ContentType.json;
          response.write(jsonEncode(post));
        } else {
          response.statusCode = 404;
        }
      } else if (_files.where((file) => _pathOf(file) == path).firstOrNull
          case final file?) {
        _file(request, _bytesOf(file.bitrate, file.size));
      } else {
        response.statusCode = 404;
      }
    } finally {
      await response.close();
    }
  }

  void _file(HttpRequest request, Uint8List bytes) {
    final response = request.response;

    if (postRequests < filesForbiddenUntilPosts) {
      response.statusCode = 403;

      return;
    }

    final range = RegExp(
      r'^bytes=(\d+)-(\d*)$',
    ).firstMatch(request.headers.value('range') ?? '');

    if (range == null) {
      requests.add('${request.uri.path}.full');
      response.contentLength = bytes.length;
      response.add(bytes);

      return;
    }

    final start = int.parse(range.group(1)!);
    final requestedEnd = range.group(2)!.isEmpty
        ? bytes.length - 1
        : int.parse(range.group(2)!);
    final end = requestedEnd < bytes.length ? requestedEnd : bytes.length - 1;

    if (end > start) requests.add('${request.uri.path}.full');

    response
      ..statusCode = 206
      ..contentLength = end - start + 1;
    response.headers.set('content-range', 'bytes $start-$end/${bytes.length}');
    response.add(bytes.sublist(start, end + 1));
  }

  Map<String, Object?> get _video => {
    'type': 'video',
    'media_url_https': '$origin/media/poster.jpg',
    'original_info': {'width': 1920, 'height': 1080},
    'video_info': {
      'duration_millis': 6373,
      'variants': [
        {
          'content_type': 'application/x-mpegURL',
          'url': '$origin/amplify_video/1/pl/playlist.m3u8',
        },
        for (final file in _files)
          {
            'content_type': 'video/mp4',
            'bitrate': file.bitrate,
            'url': '$origin${_pathOf(file)}?tag=16',
          },
      ],
    },
  };

  Map<String, Object?>? _post(String? id) => switch (id) {
    _id || _photoId => {
      '__typename': 'Tweet',
      'id_str': id,
      'text':
          'Returning to work &amp; playing #WolverinePS5.\n'
          ' https://t.co/kHTZLnZcYf',
      'user': {'name': 'PlayStation', 'screen_name': 'PlayStation'},
      'mediaDetails': [
        if (id == _photoId)
          {'type': 'photo', 'media_url_https': '$origin/media/photo.jpg'}
        else
          _video,
      ],
    },
    _ => null,
  };
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

/// yt-dlp stand-in: prints the post as a playlist of its one video and
/// "downloads" the chosen format by writing its bytes where yt-dlp would
final class _FakeYtDlpService implements YtDlpService {
  final _XServer server;
  final downloads = <String>[];
  final loadedInfos = <Map<String, dynamic>>[];

  _FakeYtDlpService(this.server);

  @override
  bool get isSupported => true;

  @override
  Future<YtDlpSetupModel> setup({bool refresh = false}) =>
      throw UnimplementedError();

  String get _info => jsonEncode({
    '_type': 'playlist',
    'id': _id,
    'entries': [
      {
        'id': '2102035848829038592',
        'display_id': _id,
        'title': 'PlayStation - Returning to work & playing... #1',
        'description':
            'Returning to work &amp; playing #WolverinePS5. '
            'https://t.co/kHTZLnZcYf',
        'uploader': 'PlayStation',
        'uploader_id': 'PlayStation',
        'duration': 6.373,
        'view_count': 1283158,
        'thumbnail': '${server.origin}/media/poster.jpg',
        'formats': [
          {
            'format_id': 'hls-6670',
            'url': '${server.origin}/amplify_video/1/pl/1080.m3u8',
            'protocol': 'm3u8_native',
            'vcodec': 'avc1.640032',
            'acodec': 'none',
            'width': 1920,
            'height': 1080,
          },
          for (final file in _files)
            {
              'format_id': 'http-${file.bitrate ~/ 1000}',
              'url': '${server.origin}${_pathOf(file)}?tag=16',
              'protocol': 'https',
              'width': file.width,
              'height': file.height,
              'tbr': file.bitrate ~/ 1000,
              'filesize_approx': file.size * 2,
            },
        ],
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
    final info = arguments[arguments.indexOf('--load-info-json') + 1];
    final bitrate = int.parse(format.substring('http-'.length)) * 1000;
    final file = _files.firstWhere((file) => file.bitrate == bitrate);

    downloads.add(format);
    loadedInfos.add(
      jsonDecode(await File(info).readAsString()) as Map<String, dynamic>,
    );
    await File(output).writeAsBytes(_bytesOf(bitrate, file.size));

    return const YtDlpRunResult(exitCode: 0);
  }
}

void main() {
  late Directory root;
  late _XServer server;
  late _TestFileSystemService fileSystemService;
  late RemoteXDataSource dataSource;
  late XVideoRepository repository;

  setUpAll(loadTestTranslations);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('x-repository');
    server = _XServer();
    await server.start();
    fileSystemService = _TestFileSystemService(root);
    dataSource = RemoteXDataSourceImpl(
      apiProvider: ApiProvider(),
      syndicationOrigin: server.origin,
    );
    repository = XVideoRepository(
      remoteXDataSource: dataSource,
      fileSystemService: fileSystemService,
    );
  });

  tearDown(() async {
    await server.close();
    await root.delete(recursive: true);
  });

  Future<OperationResult<DownloadedFileModel>> download(
    VideoRepositoryInterface repository, {
    String quality = '360',
    List<DownloadStreamModel> streams = const [],
    void Function(List<DownloadStreamModel> streams)? onStreamsSelected,
  }) => repository.downloadVideo(
    taskId: 'task-1',
    url: _url,
    quality: quality,
    streams: streams,
    onStreamsSelected: onStreamsSelected,
  );

  test('пост X: текст в заголовке, точные размеры файлов', () async {
    final result = await repository.getVideoInfo(_url);

    expect(result.failure, isNull, reason: result.failure?.message);

    final video = result.requireData;

    expect(video.id, _id);
    expect(video.title, _title);
    expect(video.channel, 'PlayStation');
    expect(video.duration, 6.373);
    expect(video.url, _url);
    expect(video.thumbnail, '${server.origin}/media/poster.jpg');
    expect(
      video.qualities.map(
        (quality) => (quality.id, quality.label, quality.size),
      ),
      [
        ('720', '720p', 240000),
        ('360', '360p', 150000),
        ('270', '270p', 90000),
      ],
    );
    expect(server.tokens, [RemoteXDataSourceImpl.syndicationToken(_id)]);

    /// A size check reads one byte, not the file
    expect(server.downloads(832000), isEmpty);
  });

  test('встроенный загрузчик качает файл качества и сохраняет его', () async {
    final selected = <DownloadStreamModel>[];
    final result = await download(
      repository,
      onStreamsSelected: selected.addAll,
    );

    expect(result.failure, isNull, reason: result.failure?.message);

    /// A file name does not end with a dot
    expect(
      result.requireData.path,
      p.join(
        root.path,
        'Downloads',
        'Returning to work & playing #WolverinePS5.mp4',
      ),
    );
    expect(selected.single.itag, 832000);
    expect(
      await File(result.requireData.path).readAsBytes(),
      _bytesOf(832000, 150000),
    );
    expect(server.downloads(2176000), isEmpty);
    expect(
      Directory(
        p.join(root.path, 'Unfinished downloads', 'task-1'),
      ).existsSync(),
      isFalse,
    );
  });

  test(
    'файл отказал (403): пост читается заново, и загрузка продолжается',
    () async {
      server.filesForbiddenUntilPosts = 2;

      final result = await download(repository);

      expect(result.failure, isNull, reason: result.failure?.message);
      expect(server.postRequests, 2);
    },
  );

  test('продолжение после паузы берёт тот же файл, что и раньше', () async {
    final result = await download(
      repository,
      streams: const [
        DownloadStreamModel(
          role: DownloadStreamRole.video,
          itag: 2176000,
          contentLength: 240000,
        ),
      ],
    );

    expect(result.failure, isNull, reason: result.failure?.message);
    expect(server.downloads(2176000), isNotEmpty);
    expect(server.downloads(832000), isEmpty);
  });

  for (final (name, url, code) in [
    (
      'удалённый пост',
      'https://x.com/PlayStation/status/1',
      const VideoErrorCodes().xUnavailable,
    ),
    (
      'пост только с фото',
      'https://x.com/PlayStation/status/$_photoId',
      const VideoErrorCodes().xNoVideo,
    ),
  ]) {
    test('$name — своя ошибка', () async {
      final result = await repository.getVideoInfo(url);

      expect(result.failure?.code, code);
    });
  }

  test('ссылка не на X — своя ошибка', () async {
    final result = await repository.getVideoInfo(
      'https://youtu.be/kgA8JPY2lIA',
    );

    expect(result.failure?.message, 'Это не ссылка на пост X (Twitter).');
  });

  group('yt-dlp', () {
    late _FakeYtDlpService ytDlpService;
    late XYtDlpVideoRepository ytDlpRepository;

    setUp(() {
      ytDlpService = _FakeYtDlpService(server);
      ytDlpRepository = XYtDlpVideoRepository(
        ytDlpService: ytDlpService,
        remoteXDataSource: dataSource,
        fileSystemService: fileSystemService,
      );
    });

    test('качества те же, что у встроенного загрузчика: без HLS, с точными '
        'размерами', () async {
      final result = await ytDlpRepository.getVideoInfo(_url);

      expect(result.failure, isNull, reason: result.failure?.message);
      expect(result.requireData.id, _id);
      expect(result.requireData.title, '$_title #1');
      expect(result.requireData.channel, 'PlayStation');
      expect(result.requireData.viewCount, 1283158);
      expect(
        result.requireData.qualities.map(
          (quality) => (quality.id, quality.size),
        ),
        [('720', 240000), ('360', 150000), ('270', 90000)],
      );
    });

    test('скачивает формат из информации одного видео поста', () async {
      final result = await download(ytDlpRepository);

      expect(result.failure, isNull, reason: result.failure?.message);
      expect(ytDlpService.downloads, ['http-832']);
      expect(ytDlpService.loadedInfos.single['display_id'], _id);
      expect(ytDlpService.loadedInfos.single.containsKey('entries'), isFalse);
      expect(
        await File(result.requireData.path).readAsBytes(),
        _bytesOf(832000, 150000),
      );
    });
  });

  test('ссылки всех сайтов уходят в репозиторий своего сайта', () async {
    final instagram = _RecordingRepository();
    final x = _RecordingRepository();
    final router = SourceVideoRepository({
      VideoSourceModel.youtube: _RecordingRepository(),
      VideoSourceModel.rutube: _RecordingRepository(),
      VideoSourceModel.tiktok: _RecordingRepository(),
      VideoSourceModel.instagram: instagram,
      VideoSourceModel.x: x,
    });

    await router.getVideoInfo('https://www.instagram.com/reel/DZT71H-BJuK/');
    await router.getVideoInfo(_url);
    await router.getVideoInfo('https://twitter.com/i/status/$_id');

    final unsupported = await router.getVideoInfo('https://vk.com/video1_2');

    expect(instagram.urls, hasLength(1));
    expect(x.urls, [_url, 'https://twitter.com/i/status/$_id']);
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
