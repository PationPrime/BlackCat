// Live Instagram download check (network, about two megabytes). Not part of
// the regular run:
//   $env:INSTAGRAM_LIVE='1'; flutter test --tags live
// The yt-dlp test runs when yt-dlp is installed on the computer
@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:peeky_cat/src/app/api/api.dart';
import 'package:peeky_cat/src/app/data_sources/data_sources.dart';
import 'package:peeky_cat/src/app/operation_result/operation_result.dart';
import 'package:peeky_cat/src/app/repositories/repositories.dart';
import 'package:peeky_cat/src/app/services/services.dart';

import '../../support/test_localization.dart';

/// A reel of 10 seconds: a ready 720p file and 1080p in DASH VP9
const _reel = 'https://www.instagram.com/reel/DZT71H-BJuK/?hl=en';

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
  final enabled = Platform.environment['INSTAGRAM_LIVE'] == '1';

  late Directory root;
  late _TestFileSystemService fileSystemService;
  late YtDlpService ytDlpService;
  late RemoteInstagramDataSource dataSource;

  setUpAll(() async {
    if (!enabled) return;

    loadTestTranslations();
    root = await Directory.systemTemp.createTemp('instagram-live');
    fileSystemService = _TestFileSystemService(root);
    ytDlpService = YtDlpServiceImpl(fileSystemService: fileSystemService);
    dataSource = RemoteInstagramDataSourceImpl(apiProvider: ApiProvider());
  });

  tearDownAll(() async {
    if (enabled) await root.delete(recursive: true);
  });

  /// Downloads the ready file and the DASH quality, and checks both
  Future<void> downloadBoth(
    VideoRepositoryInterface repository,
    String taskId,
  ) async {
    final info = await repository.getVideoInfo(_reel);

    expect(info.failure, isNull, reason: info.failure?.message);
    expect(info.requireData.title, isNotEmpty);
    expect(info.requireData.duration, closeTo(10, 1));
    expect(info.requireData.qualities.map((quality) => quality.label), [
      '1080p · VP9',
      '720p',
    ]);

    for (final (index, quality) in info.requireData.qualities.indexed) {
      final result = await repository.downloadVideo(
        taskId: '$taskId-$index',
        url: _reel,
        quality: quality.id,
      );

      expect(result.failure, isNull, reason: result.failure?.message);
      expect(p.extension(result.requireData.path), '.mp4');

      final probe = await _ffprobe(result.requireData.path);

      if (probe == null) {
        markTestSkipped('ffprobe is not installed: the file was not checked');

        continue;
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
        containsPair('width', quality.resolution),
      );
      expect(
        double.parse('${(probe['format'] as Map)['duration']}'),
        closeTo(10, 1),
      );
    }
  }

  test(
    'встроенный загрузчик: готовый файл и DASH рилса Instagram',
    () async {
      final repository = InstagramVideoRepository(
        remoteInstagramDataSource: dataSource,
        mediaMuxerService: const Mp4MediaMuxerServiceImpl(),
        fileSystemService: fileSystemService,
      );

      await downloadBoth(repository, 'instagram-builtin');
    },
    skip: enabled ? false : 'нужен INSTAGRAM_LIVE=1',
  );

  test(
    'yt-dlp: готовый файл и DASH рилса Instagram без ffmpeg',
    () async {
      if (!(await ytDlpService.setup()).isReady) {
        markTestSkipped('yt-dlp is not installed');

        return;
      }

      final repository = InstagramYtDlpVideoRepository(
        ytDlpService: ytDlpService,
        remoteInstagramDataSource: dataSource,
        mediaMuxerService: const Mp4MediaMuxerServiceImpl(),
        fileSystemService: fileSystemService,
      );

      await downloadBoth(repository, 'instagram-yt-dlp');
    },
    skip: enabled ? false : 'нужен INSTAGRAM_LIVE=1',
  );
}
