// Live YouTube download check (network, ~20 MB). Not part of the regular run:
//   $env:YT_LIVE='1'; flutter test --tags live
// Uses the app's saved sign-in cookies if there are any.
// JavaScript runs in Node only because flutter test does not open a WebView2 window
@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:black_cat/src/app/api/api.dart';
import 'package:black_cat/src/app/data_sources/data_sources.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/operation_result/operation_result.dart';
import 'package:black_cat/src/app/repositories/repositories.dart';
import 'package:black_cat/src/app/services/services.dart';
import 'package:black_cat/src/app/session/session_store.dart';
import 'package:black_cat/src/app/tools/tools.dart';

import '../../support/node_js_engine_service.dart';
import '../../support/test_localization.dart';

const _video = 'https://www.youtube.com/watch?v=kgA8JPY2lIA';

/// Downloads and app folders are in the test temp folder; cookies are real
class _TestFileSystemService extends FileSystemServiceImpl {
  final Directory root;

  _TestFileSystemService(this.root);

  @override
  Future<String> localAppFolder(String name) async => p.join(root.path, name);

  /// Real app sign-in cookies (path_provider is unavailable in tests)
  @override
  Future<String> supportFolder() async =>
      p.join(Platform.environment['APPDATA']!, 'com.BlackCat', 'black_cat');

  @override
  Future<String> defaultDownloadsFolder() async =>
      p.join(root.path, 'Downloads');
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

    return result.exitCode == 0
        ? jsonDecode(result.stdout as String) as Map<String, dynamic>
        : null;
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
      localAuthenticationDataSource: LocalAuthenticationDataSourceImpl(
        fileSystemService: fileSystemService,
      ),
    );

    repository = YouTubeVideoRepository(
      remoteYouTubeDataSource: RemoteYouTubeDataSourceImpl(
        apiProvider: apiProvider,
        sessionStore: sessionStore,
        localPlayerDataSource: LocalPlayerDataSourceImpl(
          fileSystemService: fileSystemService,
        ),
      ),
      remoteMediaStreamDataSource: RemoteMediaStreamDataSourceImpl(
        apiProvider: apiProvider,
      ),
      challengeSolverService: ChallengeSolverServiceImpl(
        jsEngineService: jsEngine,
        loadScript: (name) =>
            File(p.join('assets', 'ejs', name)).readAsString(),
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
    expect(
      result.requireData.qualities.map((quality) => quality.id),
      containsAll(['1080', '360', 'audio']),
    );
  }, skip: enabled ? false : 'нужен YT_LIVE=1');

  test(
    'только звук: обычный M4A',
    () async {
      final progress = <DownloadProgressModel>[];
      final result = await repository.downloadVideo(
        taskId: 'live-audio',
        url: _video,
        quality: 'audio',
        onProgress: progress.add,
      );

      expect(result.failure, isNull, reason: result.failure?.message);
      expect(p.extension(result.requireData.path), '.m4a');
      expect(
        result.requireData.sizeBytes,
        await File(result.requireData.path).length(),
      );
      expect(progress.last.percent, 100);

      final probe = await _ffprobe(result.requireData.path);

      if (probe != null) {
        expect(
          (probe['streams'] as List).map((stream) => stream['codec_type']),
          ['audio'],
        );
        expect(
          double.parse(probe['format']['duration'] as String),
          closeTo(478, 3),
        );
      }
    },
    skip: enabled ? false : 'нужен YT_LIVE=1',
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    '144p: видео и звук скачаны параллельно и собраны в MP4 на Dart',
    () async {
      final stages = <DownloadStage>{};
      final result = await repository.downloadVideo(
        taskId: 'live-144',
        url: _video,
        quality: '144',
        onProgress: (progress) => stages.add(progress.stage),
      );

      expect(result.failure, isNull, reason: result.failure?.message);
      expect(p.extension(result.requireData.path), '.mp4');
      expect(stages, {DownloadStage.downloading, DownloadStage.processing});

      final probe = await _ffprobe(result.requireData.path);

      if (probe != null) {
        final streams = probe['streams'] as List;

        expect(
          streams.map(
            (stream) => '${stream['codec_type']}:${stream['codec_name']}',
          ),
          ['video:h264', 'audio:aac'],
        );
        expect(streams.first['height'], 144);
        expect(
          double.parse(probe['format']['duration'] as String),
          closeTo(478, 3),
        );
      }
    },
    skip: enabled ? false : 'нужен YT_LIVE=1',
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'пауза и продолжение: докачивает с места остановки',
    () async {
      const taskId = 'live-resume';
      final cancellation = DownloadCancellation();
      var streams = <DownloadStreamModel>[];
      var pausedAt = 0;

      final paused = await repository.downloadVideo(
        taskId: taskId,
        url: _video,
        quality: '144',
        cancellation: cancellation,
        onStreamsSelected: (selected) => streams = selected,
        onProgress: (progress) {
          pausedAt = progress.downloadedBytes ?? 0;

          if (pausedAt > 1024 * 1024) {
            cancellation.cancel();
          }
        },
      );

      expect(paused.isFailed, isTrue);
      expect(streams, hasLength(2));
      expect(pausedAt, greaterThan(1024 * 1024));

      final progress = <DownloadProgressModel>[];
      final resumed = await repository.downloadVideo(
        taskId: taskId,
        url: _video,
        quality: '144',
        streams: streams,
        onProgress: progress.add,
      );

      expect(resumed.failure, isNull, reason: resumed.failure?.message);

      /// The first report already counts what was downloaded before the pause
      expect(progress.first.downloadedBytes, greaterThan(1024 * 1024));
      expect(
        progress.first.totalBytes,
        streams.fold<int>(0, (sum, stream) => sum + stream.contentLength),
      );

      final probe = await _ffprobe(resumed.requireData.path);

      if (probe != null) {
        expect(
          double.parse(probe['format']['duration'] as String),
          closeTo(478, 3),
        );
      }
    },
    skip: enabled ? false : 'нужен YT_LIVE=1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
