// Live RuTube download check (network, a few MB). Not part of the regular run:
//   $env:RUTUBE_LIVE='1'; flutter test --tags live
// The yt-dlp test runs when yt-dlp is installed on the computer
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

import '../../support/test_localization.dart';

/// A short of 83 seconds
const _short = 'https://rutube.ru/shorts/7fe803e5db2951c0a6097232efc4a439/';

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

Future<Map<String, dynamic>?> _ffprobe(String path) async {
  try {
    final result = await Process.run('ffprobe', [
      '-v',
      'error',
      '-show_entries',
      'stream=codec_type,codec_name:format=duration,format_name',
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
  final enabled = Platform.environment['RUTUBE_LIVE'] == '1';

  late Directory root;
  late _TestFileSystemService fileSystemService;
  late YtDlpService ytDlpService;

  setUpAll(() async {
    if (!enabled) return;

    loadTestTranslations();
    root = await Directory.systemTemp.createTemp('rutube-live');
    fileSystemService = _TestFileSystemService(root);
    ytDlpService = YtDlpServiceImpl(fileSystemService: fileSystemService);
  });

  tearDownAll(() async {
    if (enabled) await root.delete(recursive: true);
  });

  /// Downloads the lowest quality and checks the file
  Future<void> downloadLowest(
    VideoRepositoryInterface repository,
    String taskId,
  ) async {
    final info = await repository.getVideoInfo(_short);

    expect(info.failure, isNull, reason: info.failure?.message);
    expect(info.requireData.title, isNotEmpty);
    expect(info.requireData.duration, closeTo(83, 1));

    final lowest = info.requireData.qualities.last;
    final progress = <DownloadProgressModel>[];
    final result = await repository.downloadVideo(
      taskId: taskId,
      url: _short,
      quality: lowest.id,
      onProgress: progress.add,
    );

    expect(result.failure, isNull, reason: result.failure?.message);
    expect(p.extension(result.requireData.path), '.mp4');
    expect(
      progress.map((value) => value.stage),
      contains(DownloadStage.processing),
    );

    final probe = await _ffprobe(result.requireData.path);

    if (probe == null) {
      markTestSkipped('ffprobe is not installed: the file was not checked');

      return;
    }

    expect(
      (probe['streams'] as List).map((stream) => (stream as Map)['codec_name']),
      unorderedEquals(['h264', 'aac']),
    );
    expect(
      double.parse('${(probe['format'] as Map)['duration']}'),
      closeTo(83, 1.5),
    );
  }

  test(
    'встроенный загрузчик: HLS-сегменты RuTube собираются в MP4',
    () async {
      final repository = RuTubeVideoRepository(
        remoteRuTubeDataSource: RemoteRuTubeDataSourceImpl(
          apiProvider: ApiProvider(),
        ),
        mediaMuxerService: const Mp4MediaMuxerServiceImpl(),
        fileSystemService: fileSystemService,
      );

      await downloadLowest(repository, 'rutube-builtin');
    },
    skip: enabled ? false : 'нужен RUTUBE_LIVE=1',
  );

  test(
    'yt-dlp: поток RuTube перепаковывается в MP4 без ffmpeg',
    () async {
      if (!(await ytDlpService.setup()).isReady) {
        markTestSkipped('yt-dlp is not installed');

        return;
      }

      final repository = RuTubeYtDlpVideoRepository(
        ytDlpService: ytDlpService,
        mediaMuxerService: const Mp4MediaMuxerServiceImpl(),
        fileSystemService: fileSystemService,
      );

      await downloadLowest(repository, 'rutube-yt-dlp');
    },
    skip: enabled ? false : 'нужен RUTUBE_LIVE=1',
  );
}
