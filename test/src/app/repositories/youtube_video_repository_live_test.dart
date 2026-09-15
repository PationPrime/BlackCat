// Живая проверка загрузки с YouTube (сеть, ~20 МБ). Не входит в обычный прогон:
//   $env:YT_LIVE='1'; flutter test --tags live
// Использует сохранённые cookies входа приложения, если они есть.
// JavaScript исполняется в Node только потому, что flutter test не открывает окно WebView2
@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:youtube_downloader/src/app/api/api.dart';
import 'package:youtube_downloader/src/app/data_sources/data_sources.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/operation_result/operation_result.dart';
import 'package:youtube_downloader/src/app/repositories/repositories.dart';
import 'package:youtube_downloader/src/app/services/services.dart';
import 'package:youtube_downloader/src/app/session/session_store.dart';

import '../../support/node_js_engine_service.dart';
import '../../support/test_localization.dart';

const _video = 'https://www.youtube.com/watch?v=kgA8JPY2lIA';

/// «Загрузки» и папки приложения — во временной папке теста; cookies — настоящие
class _TestFileSystemService extends FileSystemServiceImpl {
  final Directory root;

  _TestFileSystemService(this.root);

  @override
  Future<String> localAppFolder(String name) async => p.join(root.path, name);

  /// Настоящие cookies входа приложения (path_provider в тестах недоступен)
  @override
  Future<String> supportFolder() async =>
      p.join(Platform.environment['APPDATA']!, 'com.ytdownload', 'youtube_downloader');

  @override
  Future<String> moveToDownloads(String filePath, {String? title}) async {
    final target = p.join(root.path, 'Downloads', p.basename(filePath));

    await Directory(p.dirname(target)).create(recursive: true);

    return (await File(filePath).rename(target)).path;
  }
}

Future<Map<String, dynamic>?> _ffprobe(String path) async {
  try {
    final result = await Process.run('ffprobe', [
      '-v',
      'error',
      '-show_entries',
      'stream=codec_type,codec_name,height:format=duration,format_name',
      '-of',
      'json',
      path,
    ]);

    return result.exitCode == 0 ? jsonDecode(result.stdout as String) as Map<String, dynamic> : null;
  } on ProcessException {
    return null;
  }
}

void main() {
  final enabled = Platform.environment['YT_LIVE'] == '1';

  late Directory root;
  late NodeJsEngineService jsEngine;
  late VideoRepositoryInterface repository;

  setUpAll(() async {
    if (!enabled) return;

    loadTestTranslations();
    root = await Directory.systemTemp.createTemp('yt-live');
    jsEngine = NodeJsEngineService();

    final fileSystemService = _TestFileSystemService(root);
    final apiProvider = ApiProvider();
    final sessionStore = SessionStore(
      localAuthenticationDataSource: LocalAuthenticationDataSourceImpl(fileSystemService: fileSystemService),
    );

    repository = YouTubeVideoRepository(
      remoteYouTubeDataSource: RemoteYouTubeDataSourceImpl(
        apiProvider: apiProvider,
        sessionStore: sessionStore,
        localPlayerDataSource: LocalPlayerDataSourceImpl(fileSystemService: fileSystemService),
      ),
      remoteMediaStreamDataSource: RemoteMediaStreamDataSourceImpl(apiProvider: apiProvider),
      challengeSolverService: ChallengeSolverServiceImpl(
        jsEngineService: jsEngine,
        loadScript: (name) => File(p.join('assets', 'ejs', name)).readAsString(),
      ),
      mediaMuxerService: const Mp4MediaMuxerServiceImpl(),
      fileSystemService: fileSystemService,
      sessionStore: sessionStore,
    );
  });

  tearDownAll(() async {
    if (!enabled) return;

    jsEngine.dispose();
    await root.delete(recursive: true);
  });

  test('информация о видео без yt-dlp', () async {
    final result = await repository.getVideoInfo(_video);

    expect(result.failure, isNull, reason: result.failure?.message);
    expect(result.requireData.title, isNotEmpty);
    expect(result.requireData.qualities.map((quality) => quality.id), containsAll(['1080', '360', 'audio']));
  }, skip: enabled ? false : 'нужен YT_LIVE=1');

  test('только звук: обычный M4A', () async {
    final progress = <DownloadProgressModel>[];
    final result = await repository.downloadVideo(url: _video, quality: 'audio', onProgress: progress.add);

    expect(result.failure, isNull, reason: result.failure?.message);
    expect(p.extension(result.requireData), '.m4a');
    expect(progress.last.percent, 100);

    final probe = await _ffprobe(result.requireData);

    if (probe != null) {
      expect((probe['streams'] as List).map((stream) => stream['codec_type']), ['audio']);
      expect(double.parse(probe['format']['duration'] as String), closeTo(478, 3));
    }
  }, skip: enabled ? false : 'нужен YT_LIVE=1', timeout: const Timeout(Duration(minutes: 3)));

  test('144p: видео и звук скачаны параллельно и собраны в MP4 на Dart', () async {
    final stages = <DownloadStage>{};
    final result = await repository.downloadVideo(
      url: _video,
      quality: '144',
      onProgress: (progress) => stages.add(progress.stage),
    );

    expect(result.failure, isNull, reason: result.failure?.message);
    expect(p.extension(result.requireData), '.mp4');
    expect(stages, {DownloadStage.downloading, DownloadStage.processing});

    final probe = await _ffprobe(result.requireData);

    if (probe != null) {
      final streams = probe['streams'] as List;

      expect(streams.map((stream) => '${stream['codec_type']}:${stream['codec_name']}'), ['video:h264', 'audio:aac']);
      expect(streams.first['height'], 144);
      expect(double.parse(probe['format']['duration'] as String), closeTo(478, 3));
    }
  }, skip: enabled ? false : 'нужен YT_LIVE=1', timeout: const Timeout(Duration(minutes: 3)));
}
