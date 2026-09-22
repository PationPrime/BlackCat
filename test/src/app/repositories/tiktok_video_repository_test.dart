import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:peeky_cat/src/app/api/api.dart';
import 'package:peeky_cat/src/app/data_sources/data_sources.dart';
import 'package:peeky_cat/src/app/errors/errors.dart';
import 'package:peeky_cat/src/app/models/models.dart';
import 'package:peeky_cat/src/app/operation_result/operation_result.dart';
import 'package:peeky_cat/src/app/repositories/repositories.dart';
import 'package:peeky_cat/src/app/services/services.dart';
import 'package:peeky_cat/src/app/tools/tools.dart';

import '../../support/test_localization.dart';

const _videoId = '7664657841843719457';
const _missingId = '7000000000000000001';
const _photoId = '7000000000000000002';
const _url =
    'https://www.tiktok.com/@bmw/video/$_videoId?is_from_webapp=1&sender_device=pc';
const _title = 'Закат у штаб-квартиры 🌇 #BMW';

/// Files of the page: bitrate, codec, picture size and length
const _files = [
  (bitrate: 593369, codec: 'h264', width: 576, height: 1024, size: 180000),
  (bitrate: 1059315, codec: 'h264', width: 576, height: 1024, size: 240000),
  (bitrate: 512954, codec: 'h265_hvc1', width: 576, height: 1024, size: 120000),
  (
    bitrate: 1048425,
    codec: 'h265_hvc1',
    width: 1080,
    height: 1920,
    size: 300000,
  ),
];

Uint8List _bytesOf(int bitrate, int size) =>
    Uint8List.fromList([for (var i = 0; i < size; i++) (i + bitrate) % 251]);

/// TikTok stand-in: video pages that set cookies, and files that are given
/// only with the cookies and the page as the referrer
final class _TikTokServer {
  final requests = <String>[];

  /// Files answer 403 until the page was asked this many times: the cookies
  /// of the earlier pages have expired
  var filesForbiddenUntilPages = 0;

  late final HttpServer _server;

  String get origin => 'http://${_server.address.host}:${_server.port}';

  int get pageRequests =>
      requests.where((path) => path.startsWith('/@')).length;

  List<String> fileRequests(int bitrate) =>
      requests.where((path) => path == '/file/$bitrate.mp4').toList();

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
      if (RegExp(r'^/@[^/]+/video/(\d+)$').firstMatch(path) case final match?) {
        response.headers
          ..contentType = ContentType.html
          ..add('set-cookie', 'tt_chain_token=token-$pageRequests; Path=/')
          ..add('set-cookie', 'ttwid=1%7Cabc; Path=/; HttpOnly');
        response.write(_page(match.group(1)!));
      } else if (RegExp(r'^/file/(\d+)\.mp4$').firstMatch(path)
          case final match?) {
        _file(request, int.parse(match.group(1)!));
      } else {
        response.statusCode = 404;
      }
    } finally {
      await response.close();
    }
  }

  void _file(HttpRequest request, int bitrate) {
    final response = request.response;
    final cookie = request.headers.value('cookie') ?? '';
    final referer = request.headers.value('referer') ?? '';

    if (!cookie.contains('tt_chain_token=token-') ||
        !cookie.contains('ttwid=') ||
        !referer.startsWith('$origin/@') ||
        pageRequests < filesForbiddenUntilPages) {
      response.statusCode = 403;

      return;
    }

    final file = _files.firstWhere((file) => file.bitrate == bitrate);
    final bytes = _bytesOf(bitrate, file.size);
    final range = RegExp(
      r'^bytes=(\d+)-(\d*)$',
    ).firstMatch(request.headers.value('range') ?? '');

    if (range == null) {
      response.contentLength = bytes.length;
      response.add(bytes);

      return;
    }

    final start = int.parse(range.group(1)!);
    final end = range.group(2)!.isEmpty
        ? bytes.length - 1
        : int.parse(range.group(2)!);

    response
      ..statusCode = 206
      ..contentLength = end - start + 1;
    response.headers.set('content-range', 'bytes $start-$end/${bytes.length}');
    response.add(bytes.sublist(start, end + 1));
  }

  String _page(String id) {
    final detail = switch (id) {
      _missingId => {'statusCode': 10204, 'statusMsg': 'item doesn\'t exist'},
      _ => {
        'statusCode': 0,
        'itemInfo': {
          'itemStruct': {
            'id': id,
            'desc': 'Закат у штаб-квартиры\n🌇  #BMW ',
            'author': {'uniqueId': 'bmw', 'nickname': 'BMW'},
            'stats': {'playCount': 9100000},
            if (id == _photoId) 'imagePost': {'images': <Object>[]},
            'video': {
              'duration': 7,
              'cover': '$origin/cover.jpg',
              'bitrateInfo': [
                for (final file in _files)
                  {
                    'Bitrate': file.bitrate,
                    'CodecType': file.codec,
                    'PlayAddr': {
                      'UrlList': ['$origin/file/${file.bitrate}.mp4'],
                      'DataSize': '${file.size}',
                      'Width': file.width,
                      'Height': file.height,
                    },
                  },
              ],
            },
          },
        },
      },
    };

    return '<html><head></head><body>'
        '<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" '
        'type="application/json">'
        '${jsonEncode({
          '__DEFAULT_SCOPE__': {'webapp.video-detail': detail},
        })}'
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

/// yt-dlp stand-in: prints the info of the page and "downloads" the chosen
/// format by writing its bytes where yt-dlp would
final class _FakeYtDlpService implements YtDlpService {
  final String Function() infoJson;
  final downloads = <List<String>>[];

  _FakeYtDlpService(this.infoJson);

  @override
  bool get isSupported => true;

  @override
  Future<YtDlpSetupModel> setup({bool refresh = false}) =>
      throw UnimplementedError();

  @override
  Future<YtDlpRunResult> run(
    List<String> arguments, {
    ValueChanged<String>? onLine,
    DownloadCancellation? cancellation,
  }) async {
    if (arguments.contains('--dump-single-json')) {
      return YtDlpRunResult(exitCode: 0, stdout: infoJson());
    }

    downloads.add(arguments);

    final format = arguments[arguments.indexOf('--format') + 1];
    final output = arguments[arguments.indexOf('--output') + 1];
    final bitrate = int.parse(RegExp(r'_(\d+)-\d+$').firstMatch(format)![1]!);
    final file = _files.firstWhere((file) => file.bitrate == bitrate);

    await File(output).writeAsBytes(_bytesOf(bitrate, file.size));

    return const YtDlpRunResult(exitCode: 0);
  }
}

/// `--dump-single-json` of the page: every file from two mirrors, plus the
/// watermarked file and the audio track
String _ytDlpInfo() => jsonEncode({
  'id': _videoId,
  'title': 'Закат у штаб-квартиры 🌇...',
  'description': 'Закат у штаб-квартиры\n🌇  #BMW ',
  'channel': 'bmw',
  'duration': 7,
  'view_count': 9100000,
  'thumbnail': 'https://example.com/cover.jpg',
  'webpage_url': 'https://www.tiktok.com/@bmw/video/$_videoId',
  'formats': [
    {
      'format_id': 'audio',
      'url': 'https://example.com/audio.mp3',
      'vcodec': 'none',
      'acodec': 'mp3',
    },
    {
      'format_id': 'download',
      'url': 'https://example.com/download.mp4',
      'vcodec': 'h264',
      'acodec': 'aac',
      'format_note': 'watermarked',
    },
    for (final file in _files)
      for (final mirror in [0, 1])
        {
          'format_id':
              '${file.codec.startsWith('h265') ? 'bytevc1' : 'h264'}_'
              '${file.width}p_${file.bitrate}-$mirror',
          'url': 'https://example.com/${file.bitrate}-$mirror.mp4',
          'vcodec': file.codec.startsWith('h265') ? 'h265' : 'h264',
          'acodec': 'aac',
          'width': file.width,
          'height': file.height,
          'tbr': file.bitrate ~/ 1000,
          'filesize': file.size,
        },
  ],
});

void main() {
  late Directory root;
  late _TikTokServer server;
  late _TestFileSystemService fileSystemService;
  late TikTokVideoRepository repository;

  setUpAll(loadTestTranslations);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('tiktok-repository');
    server = _TikTokServer();
    await server.start();
    fileSystemService = _TestFileSystemService(root);
    repository = TikTokVideoRepository(
      remoteTikTokDataSource: RemoteTikTokDataSourceImpl(
        apiProvider: ApiProvider(),
        origin: server.origin,
      ),
      fileSystemService: fileSystemService,
    );
  });

  tearDown(() async {
    await server.close();
    await root.delete(recursive: true);
  });

  Future<OperationResult<DownloadedFileModel>> download({
    String quality = '576',
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
    'видео TikTok: описание в заголовке, одно качество на разрешение',
    () async {
      final result = await repository.getVideoInfo(_url);

      expect(result.failure, isNull, reason: result.failure?.message);

      final video = result.requireData;

      expect(video.id, _videoId);
      expect(video.title, _title);
      expect(video.channel, 'BMW');
      expect(video.duration, 7);
      expect(video.viewCount, 9100000);
      expect(video.url, 'https://www.tiktok.com/@bmw/video/$_videoId');
      expect(
        video.qualities.map(
          (quality) => (quality.id, quality.label, quality.size),
        ),
        [('1080', '1080p · H.265', 300000), ('576', '576p', 240000)],
      );
      expect(server.requests.first, '/@bmw/video/$_videoId');
    },
  );

  test(
    'встроенный загрузчик качает файл с куки страницы и сохраняет его',
    () async {
      final selected = <DownloadStreamModel>[];
      final result = await download(onStreamsSelected: selected.addAll);

      expect(result.failure, isNull, reason: result.failure?.message);
      expect(
        result.requireData.path,
        p.join(root.path, 'Downloads', '$_title.mp4'),
      );
      expect(selected.single.itag, 1059315);
      expect(
        await File(result.requireData.path).readAsBytes(),
        _bytesOf(1059315, 240000),
      );
      expect(server.fileRequests(593369), isEmpty);
      expect(
        Directory(
          p.join(root.path, 'Unfinished downloads', 'task-1'),
        ).existsSync(),
        isFalse,
      );
    },
  );

  test(
    'куки устарели (403): страница берётся заново, и загрузка продолжается',
    () async {
      server.filesForbiddenUntilPages = 2;

      final result = await download();

      expect(result.failure, isNull, reason: result.failure?.message);
      expect(server.pageRequests, 2);
    },
  );

  test('продолжение после паузы берёт тот же файл, что и раньше', () async {
    final result = await download(
      streams: const [
        DownloadStreamModel(
          role: DownloadStreamRole.video,
          itag: 593369,
          contentLength: 180000,
        ),
      ],
    );

    expect(result.failure, isNull, reason: result.failure?.message);
    expect(server.fileRequests(593369), isNotEmpty);
    expect(server.fileRequests(1059315), isEmpty);
  });

  test('удалённое видео: ошибка TikTok', () async {
    final result = await repository.getVideoInfo(
      'https://www.tiktok.com/@bmw/video/$_missingId',
    );

    expect(result.failure?.code, const VideoErrorCodes().tiktokUnavailable);
  });

  test('фото-пост не скачивается ни по ссылке, ни по странице', () async {
    final byLink = await repository.getVideoInfo(
      'https://www.tiktok.com/@bmw/photo/$_photoId',
    );
    final byPage = await repository.getVideoInfo(
      'https://www.tiktok.com/@bmw/video/$_photoId',
    );

    expect(byLink.failure?.code, const VideoErrorCodes().tiktokPhoto);
    expect(byLink.failure?.message, 'Это фото-пост TikTok: в нём нет видео.');
    expect(byPage.failure?.code, const VideoErrorCodes().tiktokPhoto);
    expect(server.pageRequests, 1);
  });

  test('ссылка не на TikTok — своя ошибка', () async {
    final result = await repository.getVideoInfo(
      'https://youtu.be/kgA8JPY2lIA',
    );

    expect(result.failure?.message, 'Это не ссылка на видео TikTok.');
  });

  group('yt-dlp', () {
    late _FakeYtDlpService ytDlpService;
    late TikTokYtDlpVideoRepository ytDlpRepository;

    setUp(() {
      ytDlpService = _FakeYtDlpService(_ytDlpInfo);
      ytDlpRepository = TikTokYtDlpVideoRepository(
        ytDlpService: ytDlpService,
        fileSystemService: fileSystemService,
      );
    });

    test('качества те же, что у встроенного загрузчика: без водяного знака и '
        'без повторов зеркал', () async {
      final result = await ytDlpRepository.getVideoInfo(_url);

      expect(result.failure, isNull, reason: result.failure?.message);
      expect(result.requireData.title, _title);
      expect(result.requireData.channel, 'bmw');
      expect(
        result.requireData.qualities.map(
          (quality) => (quality.id, quality.label, quality.size),
        ),
        [('1080', '1080p · H.265', 300000), ('576', '576p', 240000)],
      );
    });

    test('скачивает формат H.264 из сохранённой информации', () async {
      final result = await ytDlpRepository.downloadVideo(
        taskId: 'task-2',
        url: _url,
        quality: '576',
      );

      expect(result.failure, isNull, reason: result.failure?.message);
      expect(
        result.requireData.path,
        p.join(root.path, 'Downloads', '$_title.mp4'),
      );
      expect(
        await File(result.requireData.path).readAsBytes(),
        _bytesOf(1059315, 240000),
      );

      final arguments = ytDlpService.downloads.single;

      expect(arguments, containsAllInOrder(['--load-info-json']));
      expect(
        arguments[arguments.indexOf('--format') + 1],
        'h264_576p_1059315-0',
      );
    });
  });

  test('ссылки всех сайтов уходят в репозиторий своего сайта', () async {
    final youtube = _RecordingRepository();
    final rutube = _RecordingRepository();
    final tiktok = _RecordingRepository();
    final router = SourceVideoRepository({
      VideoSourceModel.youtube: youtube,
      VideoSourceModel.rutube: rutube,
      VideoSourceModel.tiktok: tiktok,
    });

    await router.getVideoInfo('https://youtu.be/kgA8JPY2lIA');
    await router.getVideoInfo(
      'https://rutube.ru/shorts/7fe803e5db2951c0a6097232efc4a439/',
    );
    await router.getVideoInfo(_url);
    await router.getVideoInfo('https://vm.tiktok.com/ZMabc123/');

    final unsupported = await router.getVideoInfo('https://vk.com/video1_2');

    expect(youtube.urls, hasLength(1));
    expect(rutube.urls, hasLength(1));
    expect(tiktok.urls, [_url, 'https://vm.tiktok.com/ZMabc123/']);
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
