import 'dart:convert';
import 'dart:io';

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
import '../../support/test_localization.dart';

const _videoId = '7fe803e5db2951c0a6097232efc4a439';
const _blockedId = '19bfb665a164217084d9a5b4d8a9e734';
const _liveId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _url = 'https://rutube.ru/shorts/$_videoId/';
const _fixture = 'test/src/support/fixtures/hls';
const _blockedReason =
    'Видео недоступно из-за ограничений в вашей стране, VPN или окончания '
    'прав на его показ';

/// RuTube stand-in: the player API, a master playlist of two qualities
/// (one of them from two CDNs) and the segments of the fixture
final class _RuTubeServer {
  final requests = <String>[];

  /// Segments answer 403 until the player API was asked this many times:
  /// the links of the earlier answers have expired
  var segmentsForbiddenUntilOptions = 0;

  late final HttpServer _server;

  String get origin => 'http://${_server.address.host}:${_server.port}';

  int _count(String prefix) =>
      requests.where((path) => path.startsWith(prefix)).length;

  int get optionsRequests => _count('/api/play/options/');

  List<String> segmentRequests(String variant) =>
      requests.where((path) => path.startsWith('/$variant/segment-')).toList();

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
      if (path.startsWith('/api/play/options/')) {
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode(_options(path.split('/')[4])));
      } else if (path == '/master.m3u8') {
        response.write('''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=100000,CODECS="avc1.64000c, mp4a.40.2",RESOLUTION=160x90
$origin/lo/index.m3u8?i=1
#EXT-X-STREAM-INF:BANDWIDTH=100000,CODECS="avc1.64000c, mp4a.40.2",RESOLUTION=160x90
$origin/lo-mirror/index.m3u8?i=1
#EXT-X-STREAM-INF:BANDWIDTH=200000,CODECS="avc1.64000c, mp4a.40.2",RESOLUTION=320x180
$origin/hi/index.m3u8?i=2
''');
      } else if (path.endsWith('/index.m3u8')) {
        response.write('''
#EXTM3U
#EXT-X-TARGETDURATION:2
#EXT-X-PLAYLIST-TYPE:VOD
#EXTINF:2.000,
segment-0.ts
#EXTINF:2.000,
segment-1.ts
#EXTINF:2.000,
segment-2.ts
#EXT-X-ENDLIST
''');
      } else if (path.contains('/segment-')) {
        if (optionsRequests < segmentsForbiddenUntilOptions) {
          response.statusCode = 403;
        } else {
          response.add(
            await File(p.join(_fixture, p.basename(path))).readAsBytes(),
          );
        }
      } else {
        response.statusCode = 404;
      }
    } finally {
      await response.close();
    }
  }

  Map<String, Object?> _options(String id) => switch (id) {
    _blockedId => {
      'detail': {
        'type': 'blocking_rule',
        'languages': [
          {'lang': 'rus', 'title': _blockedReason},
        ],
      },
    },
    _ => {
      'title': 'Кино без лишних слов',
      'author': {'name': 'Краткий пересказ'},
      'duration': 6000,
      'thumbnail_url': '$origin/thumb.jpg',
      'live_streams': id == _liveId
          ? {
              'hls': [
                {'url': '$origin/live.m3u8'},
              ],
            }
          : <String, Object?>{},
      'video_balancer': {
        'default': '$origin/master.m3u8',
        'm3u8': '$origin/master.m3u8',
      },
    },
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

void main() {
  late Directory root;
  late _RuTubeServer server;
  late _TestFileSystemService fileSystemService;
  late RuTubeVideoRepository repository;

  setUpAll(loadTestTranslations);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('rutube-repository');
    server = _RuTubeServer();
    await server.start();
    fileSystemService = _TestFileSystemService(root);
    repository = RuTubeVideoRepository(
      remoteRuTubeDataSource: RemoteRuTubeDataSourceImpl(
        apiProvider: ApiProvider(),
        apiOrigin: server.origin,
      ),
      mediaMuxerService: const Mp4MediaMuxerServiceImpl(),
      fileSystemService: fileSystemService,
    );
  });

  tearDown(() async {
    await server.close();
    await root.delete(recursive: true);
  });

  Future<OperationResult<DownloadedFileModel>> download({
    String quality = '90',
    List<DownloadStreamModel> streams = const [],
    void Function(List<DownloadStreamModel> streams)? onStreamsSelected,
  }) => repository.downloadVideo(
    taskId: 'task-1',
    url: _url,
    quality: quality,
    streams: streams,
    onStreamsSelected: onStreamsSelected,
  );

  test(
    'видео RuTube: одно качество на разрешение, размер по битрейту',
    () async {
      final result = await repository.getVideoInfo(_url);

      expect(result.failure, isNull, reason: result.failure?.message);

      final video = result.requireData;

      expect(video.title, 'Кино без лишних слов');
      expect(video.channel, 'Краткий пересказ');
      expect(video.duration, 6);
      expect(video.url, _url);
      expect(video.qualities.map((quality) => (quality.id, quality.size)), [
        ('180', 200000 ~/ 8 * 6),
        ('90', 100000 ~/ 8 * 6),
      ]);
    },
  );

  test(
    'встроенный загрузчик качает сегменты качества и собирает MP4',
    () async {
      final selected = <DownloadStreamModel>[];
      final result = await download(onStreamsSelected: selected.addAll);

      expect(result.failure, isNull, reason: result.failure?.message);
      expect(
        result.requireData.path,
        p.join(root.path, 'Downloads', 'Кино без лишних слов.mp4'),
      );
      expect(selected.single.itag, 100000);
      expect(server.segmentRequests('lo'), hasLength(3));
      expect(server.segmentRequests('hi'), isEmpty);

      final boxes = topLevel(await File(result.requireData.path).readAsBytes());

      expect(boxes.map((box) => box.type), ['ftyp', 'moov', 'mdat']);
      expect(boxes[1].all('trak'), hasLength(2));
      expect(
        Directory(p.join(root.path, 'Unfinished downloads', 'task-1')).existsSync(),
        isFalse,
      );
    },
  );

  test(
    'ссылки устарели (403): берутся новые, и загрузка продолжается',
    () async {
      server.segmentsForbiddenUntilOptions = 2;

      final result = await download();

      expect(result.failure, isNull, reason: result.failure?.message);
      expect(server.optionsRequests, 2);
    },
  );

  test('продолжение после паузы берёт тот же вариант, что и раньше', () async {
    final result = await download(
      streams: const [
        DownloadStreamModel(
          role: DownloadStreamRole.video,
          itag: 200000,
          contentLength: 150000,
        ),
      ],
    );

    expect(result.failure, isNull, reason: result.failure?.message);
    expect(server.segmentRequests('hi'), hasLength(3));
    expect(server.segmentRequests('lo'), isEmpty);
  });

  test('заблокированное видео: в ошибке причина от RuTube', () async {
    final result = await repository.getVideoInfo(
      'https://rutube.ru/video/$_blockedId/?playlist=346913',
    );

    expect(result.failure?.code, const VideoErrorCodes().rutubeUnavailable);
    expect(result.failure?.message, _blockedReason);
  });

  test('трансляции не скачиваются', () async {
    final result = await repository.getVideoInfo(
      'https://rutube.ru/video/$_liveId/',
    );

    expect(result.failure?.code, const VideoErrorCodes().rutubeLive);
    expect(result.failure?.message, 'Трансляции RuTube пока не скачиваются.');
  });

  test('ссылка не на RuTube — своя ошибка', () async {
    final result = await repository.getVideoInfo(
      'https://youtu.be/kgA8JPY2lIA',
    );

    expect(result.failure?.message, 'Это не ссылка на видео RuTube.');
  });

  test('ссылки всех сайтов уходят в репозиторий своего сайта', () async {
    final youtube = _RecordingRepository();
    final rutube = _RecordingRepository();
    final router = SourceVideoRepository({
      VideoSourceModel.youtube: youtube,
      VideoSourceModel.rutube: rutube,
    });

    await router.getVideoInfo('https://youtu.be/kgA8JPY2lIA');
    await router.getVideoInfo(_url);

    final unsupported = await router.getVideoInfo('https://vk.com/video1_2');

    expect(youtube.urls, ['https://youtu.be/kgA8JPY2lIA']);
    expect(rutube.urls, [_url]);
    expect(
      unsupported.failure?.message,
      'Это не ссылка на видео YouTube, RuTube, TikTok или Instagram.',
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
