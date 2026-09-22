// Live TikTok download check (network, about a megabyte). Not part of the
// regular run:
//   $env:TIKTOK_LIVE='1'; flutter test --tags live
// The yt-dlp test runs when yt-dlp is installed on the computer
@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:black_cat/src/app/api/api.dart';
import 'package:black_cat/src/app/data_sources/data_sources.dart';
import 'package:black_cat/src/app/operation_result/operation_result.dart';
import 'package:black_cat/src/app/repositories/repositories.dart';
import 'package:black_cat/src/app/services/services.dart';

import '../../support/test_localization.dart';

/// A video of 7 seconds
const _video =
    'https://www.tiktok.com/@bmw/video/7664657841843719457?is_from_webapp=1&sender_device=pc';

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
      'stream=codec_type,codec_name:format=duration',
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
  final enabled = Platform.environment['TIKTOK_LIVE'] == '1';

  late Directory root;
  late _TestFileSystemService fileSystemService;
  late YtDlpService ytDlpService;

  setUpAll(() async {
    if (!enabled) return;

    loadTestTranslations();
    root = await Directory.systemTemp.createTemp('tiktok-live');
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
    final info = await repository.getVideoInfo(_video);

    expect(info.failure, isNull, reason: info.failure?.message);
    expect(info.requireData.title, isNotEmpty);
    expect(info.requireData.duration, closeTo(7, 1));

    final lowest = info.requireData.qualities.last;
    final result = await repository.downloadVideo(
      taskId: taskId,
      url: _video,
      quality: lowest.id,
    );

    expect(result.failure, isNull, reason: result.failure?.message);
    expect(p.extension(result.requireData.path), '.mp4');

    if (lowest.size case final size?) {
      expect(result.requireData.sizeBytes, size);
    }

    final probe = await _ffprobe(result.requireData.path);

    if (probe == null) {
      markTestSkipped('ffprobe is not installed: the file was not checked');

      return;
    }

    expect(
      (probe['streams'] as List).map((stream) => (stream as Map)['codec_type']),
      unorderedEquals(['video', 'audio']),
    );
    expect(
      double.parse('${(probe['format'] as Map)['duration']}'),
      closeTo(7, 1),
    );
  }

  test(
    'встроенный загрузчик: файл TikTok скачивается с куки страницы',
    () async {
      final repository = TikTokVideoRepository(
        remoteTikTokDataSource: RemoteTikTokDataSourceImpl(
          apiProvider: ApiProvider(),
        ),
        fileSystemService: fileSystemService,
      );

      await downloadLowest(repository, 'tiktok-builtin');
    },
    skip: enabled ? false : 'нужен TIKTOK_LIVE=1',
  );

  test(
    'yt-dlp: файл TikTok скачивается из сохранённой информации',
    () async {
      if (!(await ytDlpService.setup()).isReady) {
        markTestSkipped('yt-dlp is not installed');

        return;
      }

      final repository = TikTokYtDlpVideoRepository(
        ytDlpService: ytDlpService,
        fileSystemService: fileSystemService,
      );

      await downloadLowest(repository, 'tiktok-yt-dlp');
    },
    skip: enabled ? false : 'нужен TIKTOK_LIVE=1',
  );
}
