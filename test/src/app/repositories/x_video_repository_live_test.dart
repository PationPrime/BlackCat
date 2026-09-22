// Live X download check (network, about a megabyte). Not part of the
// regular run:
//   $env:X_LIVE='1'; flutter test --tags live
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

/// A post with a video of 6 seconds in 270p, 360p, 720p and 1080p
const _post = 'https://x.com/PlayStation/status/2102042791807263094/video/1';

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
      'stream=codec_type,codec_name,width,height:format=duration',
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
  final enabled = Platform.environment['X_LIVE'] == '1';

  late Directory root;
  late _TestFileSystemService fileSystemService;
  late YtDlpService ytDlpService;
  late RemoteXDataSource dataSource;

  setUpAll(() async {
    if (!enabled) return;

    loadTestTranslations();
    root = await Directory.systemTemp.createTemp('x-live');
    fileSystemService = _TestFileSystemService(root);
    ytDlpService = YtDlpServiceImpl(fileSystemService: fileSystemService);
    dataSource = RemoteXDataSourceImpl(apiProvider: ApiProvider());
  });

  tearDownAll(() async {
    if (enabled) await root.delete(recursive: true);
  });

  /// Downloads the 360p file and checks it
  Future<void> download360(
    VideoRepositoryInterface repository,
    String taskId,
  ) async {
    final info = await repository.getVideoInfo(_post);

    expect(info.failure, isNull, reason: info.failure?.message);
    expect(info.requireData.title, startsWith('Returning to work'));
    expect(info.requireData.channel, 'PlayStation');
    expect(info.requireData.duration, closeTo(6.4, 0.5));
    expect(info.requireData.qualities.map((quality) => quality.label), [
      '1080p',
      '720p',
      '360p',
      '270p',
    ]);

    final quality = info.requireData.qualities[2];
    final result = await repository.downloadVideo(
      taskId: taskId,
      url: _post,
      quality: quality.id,
    );

    expect(result.failure, isNull, reason: result.failure?.message);
    expect(p.extension(result.requireData.path), '.mp4');
    expect(result.requireData.sizeBytes, quality.size);

    final probe = await _ffprobe(result.requireData.path);

    if (probe == null) {
      markTestSkipped('ffprobe is not installed: the file was not checked');

      return;
    }

    final streams = [
      for (final stream in probe['streams'] as List) stream as Map,
    ];

    expect(
      streams.map((stream) => stream['codec_type']),
      unorderedEquals(['video', 'audio']),
    );
    expect(
      streams.firstWhere((stream) => stream['codec_type'] == 'video'),
      containsPair('height', 360),
    );
  }

  test(
    'встроенный загрузчик: видео поста X через API для встраивания',
    () async {
      final repository = XVideoRepository(
        remoteXDataSource: dataSource,
        fileSystemService: fileSystemService,
      );

      await download360(repository, 'x-builtin');
    },
    skip: enabled ? false : 'нужен X_LIVE=1',
  );

  test(
    'yt-dlp: видео поста X из сохранённой информации',
    () async {
      if (!(await ytDlpService.setup()).isReady) {
        markTestSkipped('yt-dlp is not installed');

        return;
      }

      final repository = XYtDlpVideoRepository(
        ytDlpService: ytDlpService,
        remoteXDataSource: dataSource,
        fileSystemService: fileSystemService,
      );

      await download360(repository, 'x-yt-dlp');
    },
    skip: enabled ? false : 'нужен X_LIVE=1',
  );
}
