import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:black_cat/src/app/dto/dto.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/storage/database/database.dart';
import 'package:black_cat/src/app/storage/database/providers/providers.dart';

DownloadTaskDto _task(
  String id, {
  DownloadTaskSection section = DownloadTaskSection.queue,
  DownloadTaskStatus status = DownloadTaskStatus.queued,
  int position = 0,
  List<DownloadStreamDto> streams = const [],
}) => DownloadTaskDto(
  id: id,
  videoId: 'video-$id',
  videoUrl: 'https://www.youtube.com/watch?v=video-$id',
  title: 'Обзор «$id»',
  channel: 'Канал',
  durationSeconds: 478,
  viewCount: 1200,
  qualityId: '1080',
  qualityKind: QualityKind.video,
  qualityLabel: '1080p60',
  qualityResolution: 1080,
  qualitySize: 52428800,
  status: status,
  section: section,
  position: position,
  createdAt: DateTime(2026, 9, 1, 12),
  updatedAt: DateTime(2026, 9, 1, 12, 5),
  streams: streams,
);

const _streams = [
  DownloadStreamDto(
    role: DownloadStreamRole.video,
    itag: 137,
    contentLength: 50000000,
  ),
  DownloadStreamDto(
    role: DownloadStreamRole.audio,
    itag: 140,
    contentLength: 2428800,
  ),
];

void main() {
  late AppDatabase database;
  late DownloadTaskTableProvider provider;

  setUp(() {
    database = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory()),
    );
    provider = DownloadTaskTableProvider(databaseInstance: database);
  });

  tearDown(() => database.close());

  test(
    'saveTasks и getTasks: загрузка вместе с потоками, по разделам и местам',
    () async {
      await provider.saveTasks([
        _task(
          'finished',
          section: DownloadTaskSection.finished,
          status: DownloadTaskStatus.done,
        ),
        _task('second', position: 1),
        _task(
          'failed',
          section: DownloadTaskSection.failed,
          status: DownloadTaskStatus.failed,
        ),
        _task(
          'active',
          section: DownloadTaskSection.active,
          status: DownloadTaskStatus.paused,
          streams: _streams,
        ),
        _task('first'),
      ]);

      final tasks = await provider.getTasks();

      expect(
        [for (final task in tasks) task.id],
        ['active', 'first', 'second', 'failed', 'finished'],
      );
      expect(tasks[3].section, DownloadTaskSection.failed);

      final active = tasks.first;

      expect(active.status, DownloadTaskStatus.paused);
      expect(active.title, 'Обзор «active»');
      expect(active.qualityKind, QualityKind.video);
      expect(active.qualityLabel, '1080p60');
      expect(active.durationSeconds, 478);
      expect(active.createdAt, DateTime(2026, 9, 1, 12));
      expect(
        [
          for (final stream in active.streams)
            (stream.role, stream.itag, stream.contentLength),
        ],
        [
          (DownloadStreamRole.video, 137, 50000000),
          (DownloadStreamRole.audio, 140, 2428800),
        ],
      );
    },
  );

  test('saveTasks перезаписывает загрузку и её потоки', () async {
    await provider.saveTasks([_task('a', streams: _streams)]);
    await provider.saveTasks([
      _task(
        'a',
        section: DownloadTaskSection.active,
        status: DownloadTaskStatus.downloading,
        streams: [_streams.last],
      ),
    ]);

    final task = (await provider.getTasks()).single;

    expect(task.section, DownloadTaskSection.active);
    expect(task.streams.single.itag, 140);
  });

  test('updateProgress пишет только счётчики байт', () async {
    await provider.saveTasks([
      _task('a', status: DownloadTaskStatus.downloading),
    ]);
    await provider.updateProgress(
      taskId: 'a',
      downloadedBytes: 1024,
      totalBytes: 4096,
    );

    final task = (await provider.getTasks()).single;

    expect(task.downloadedBytes, 1024);
    expect(task.totalBytes, 4096);
    expect(task.status, DownloadTaskStatus.downloading);
  });

  test('deleteTasks удаляет загрузку и каскадно её потоки', () async {
    await provider.saveTasks([
      _task('a', streams: _streams),
      _task('b', position: 1),
    ]);
    await provider.deleteTasks(['a']);

    expect([for (final task in await provider.getTasks()) task.id], ['b']);
    expect(
      await database.select(database.downloadTaskStreamsTable).get(),
      isEmpty,
    );
  });

  test(
    'способ скачивания сохраняется: встроенный по умолчанию, yt-dlp как указан',
    () async {
      await provider.saveTasks([
        _task('built-in'),
        DownloadTaskDto.fromModel(
          _task('yt-dlp', position: 1).toModel().copyWith(),
        ),
      ]);

      final ytDlpTask = DownloadTaskDto.fromModel(
        DownloadTaskModel(
          id: 'yt-dlp',
          video: const VideoInfoModel(
            id: 'video',
            title: 'Видео',
            url: 'https://youtu.be/video',
            qualities: [],
          ),
          quality: const QualityModel(id: '1080', kind: QualityKind.video),
          status: DownloadTaskStatus.queued,
          section: DownloadTaskSection.queue,
          engine: DownloadEngineModel.ytDlp,
          position: 1,
          createdAt: DateTime(2026, 9, 1),
          updatedAt: DateTime(2026, 9, 1),
        ),
      );

      await provider.saveTasks([ytDlpTask]);

      final tasks = await provider.getTasks();

      expect(
        {for (final task in tasks) task.id: task.engine},
        {
          'built-in': DownloadEngineModel.builtIn,
          'yt-dlp': DownloadEngineModel.ytDlp,
        },
      );
    },
  );
}
