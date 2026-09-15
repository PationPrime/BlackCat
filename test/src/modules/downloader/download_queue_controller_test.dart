import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/shared_controllers/shared_controllers.dart';
import 'package:youtube_downloader/src/modules/downloader/controllers/controllers.dart';

import '../../support/fake_repositories.dart';

const _videoStreams = [
  DownloadStreamModel(role: DownloadStreamRole.video, itag: 160, contentLength: 800),
  DownloadStreamModel(role: DownloadStreamRole.audio, itag: 140, contentLength: 200),
];

VideoInfoModel _video(String id) => VideoInfoModel(
  id: id,
  title: 'Видео $id',
  url: 'https://www.youtube.com/watch?v=$id',
  qualities: testVideoInfo.qualities,
);

const _quality1080 = QualityModel(id: '1080', kind: QualityKind.video, label: '1080p', resolution: 1080);

/// Lets the queue change chain and running downloads complete
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

final class _Harness {
  final videoRepository = FakeVideoRepository();
  final queueRepository = FakeDownloadQueueRepository();
  final settingsRepository = FakeSettingsRepository();
  final authenticationRepository = FakeAuthenticationRepository();

  late final controller = DownloadQueueController(
    downloadQueueRepository: queueRepository,
    videoRepository: videoRepository,
    settingsRepository: settingsRepository,
    authorizationController: AuthorizationController(authenticationRepository: authenticationRepository),
  );

  DownloadQueueState get state => controller.state;

  List<FakeDownloadCall> get downloads => videoRepository.downloads;

  Future<void> add(String id, {QualityModel quality = _quality1080}) async {
    await controller.addTask(video: _video(id), quality: quality);
    await _settle();
  }

  String taskIdOf(String videoId) => state.allTasks.firstWhere((task) => task.video.id == videoId).id;

  List<String> get queueVideoIds => [for (final task in state.queue) task.video.id];
}

DownloadTaskModel _restoredTask(
  String id, {
  required DownloadTaskStatus status,
  required DownloadTaskSection section,
  int position = 0,
  int downloadedBytes = 0,
  List<DownloadStreamModel> streams = const [],
}) => DownloadTaskModel(
  id: 'task-$id',
  video: _video(id),
  quality: _quality1080,
  status: status,
  section: section,
  position: position,
  streams: streams,
  downloadedBytes: downloadedBytes,
  totalBytes: streams.isEmpty ? null : 1000,
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
);

void main() {
  test('addTask: первое видео сразу качается, следующие встают в конец очереди', () async {
    final harness = _Harness();

    await harness.add('a');

    expect(harness.state.activeTask?.video.id, 'a');
    expect(harness.state.activeTask?.status, DownloadTaskStatus.downloading);
    expect(harness.downloads.single.url, _video('a').url);
    expect(harness.downloads.single.quality, '1080');
    expect(harness.downloads.single.destinationDirectory, r'C:\Users\user\Downloads');

    await harness.add('b');
    await harness.add('c');

    expect(harness.queueVideoIds, ['b', 'c']);
    expect([for (final task in harness.state.queue) task.position], [0, 1]);
    expect(harness.downloads, hasLength(1));
    expect(harness.queueRepository.saved[harness.taskIdOf('c')]?.section, DownloadTaskSection.queue);
  });

  test('готовая загрузка уходит в скачанные с размером, временем и превью, следующая начинается сама', () async {
    final harness = _Harness();

    await harness.add('a');
    await harness.add('b');

    final beforeFinish = DateTime.now();

    harness.downloads.first.succeed(r'C:\Users\user\Downloads\Видео a.mp4', sizeBytes: 70000000);
    await _settle();

    final downloaded = harness.state.finished.single;

    expect(downloaded.video.id, 'a');
    expect(downloaded.status, DownloadTaskStatus.done);
    expect(downloaded.filePath, r'C:\Users\user\Downloads\Видео a.mp4');
    expect(downloaded.fileSizeBytes, 70000000);
    expect(downloaded.completedAt!.isBefore(beforeFinish), isFalse);
    expect(downloaded.thumbnailPath, r'C:\Thumbnails\thumb.jpg');
    expect(harness.queueRepository.thumbnailTaskIds, [downloaded.id]);
    expect(harness.queueRepository.saved[downloaded.id]?.thumbnailPath, r'C:\Thumbnails\thumb.jpg');
    expect(harness.state.activeTask?.video.id, 'b');
    expect(harness.state.queue, isEmpty);
    expect(harness.downloads.last.taskId, harness.taskIdOf('b'));
  });

  test('прогресс и выбранные потоки сохраняются для возобновления', () async {
    final harness = _Harness();

    await harness.add('a');

    final download = harness.downloads.single;

    download.selectStreams(_videoStreams);
    download.reportProgress(
      const DownloadProgressModel(DownloadStage.downloading, 40, speed: 100, eta: 6, downloadedBytes: 400, totalBytes: 1000),
    );
    await _settle();

    final activeTask = harness.state.activeTask!;

    expect(activeTask.downloadedBytes, 400);
    expect(activeTask.totalBytes, 1000);
    expect(activeTask.percent, 40);
    expect(activeTask.speed, 100);
    expect(harness.queueRepository.saved[activeTask.id]?.streams, _videoStreams);
  });

  test('startTask: активная загрузка встаёт на паузу в начало очереди, выбранное видео качается', () async {
    final harness = _Harness();

    await harness.add('a');
    await harness.add('b');
    await harness.add('c');

    harness.downloads.first
      ..selectStreams(_videoStreams)
      ..reportProgress(const DownloadProgressModel(DownloadStage.downloading, 50, downloadedBytes: 500, totalBytes: 1000));

    await harness.controller.startTask(harness.taskIdOf('c'));
    await _settle();

    expect(harness.downloads.first.isCancelled, isTrue);
    expect(harness.state.activeTask?.video.id, 'c');
    expect(harness.state.activeTask?.status, DownloadTaskStatus.downloading);
    expect(harness.queueVideoIds, ['a', 'b']);
    expect(harness.state.queue.first.status, DownloadTaskStatus.paused);
    expect(harness.state.queue.first.downloadedBytes, 500);
    expect(harness.state.queue.first.speed, isNull);
    expect(harness.downloads.last.taskId, harness.taskIdOf('c'));

    /// After "c", "a" continues with the same streams
    harness.downloads.last.succeed(r'C:\Downloads\c.mp4');
    await _settle();

    expect(harness.state.activeTask?.video.id, 'a');
    expect(harness.downloads.last.taskId, harness.taskIdOf('a'));
    expect(harness.downloads.last.streams, _videoStreams);
  });

  test('startTask во время склейки: выбранное видео начнётся сразу после неё', () async {
    final harness = _Harness();

    await harness.add('a');
    await harness.add('b');
    await harness.add('c');

    harness.downloads.first.reportProgress(
      const DownloadProgressModel(DownloadStage.processing, 100, downloadedBytes: 1000, totalBytes: 1000),
    );

    await harness.controller.startTask(harness.taskIdOf('c'));
    await _settle();

    expect(harness.downloads.first.isCancelled, isFalse);
    expect(harness.state.activeTask?.status, DownloadTaskStatus.processing);
    expect(harness.queueVideoIds, ['c', 'b']);
  });

  test('pauseActiveTask и resumeActiveTask: пауза не запускает очередь, продолжение — с тех же потоков', () async {
    final harness = _Harness();

    await harness.add('a');
    await harness.add('b');

    harness.downloads.single.selectStreams(_videoStreams);

    await harness.controller.pauseActiveTask();
    await _settle();

    expect(harness.downloads.single.isCancelled, isTrue);
    expect(harness.state.activeTask?.video.id, 'a');
    expect(harness.state.activeTask?.status, DownloadTaskStatus.paused);
    expect(harness.queueVideoIds, ['b']);
    expect(harness.downloads, hasLength(1));

    await harness.controller.resumeActiveTask();
    await _settle();

    expect(harness.state.activeTask?.status, DownloadTaskStatus.downloading);
    expect(harness.downloads, hasLength(2));
    expect(harness.downloads.last.streams, _videoStreams);
  });

  test('moveQueuedTask переставляет очередь сразу и сохраняет места', () async {
    final harness = _Harness();

    await harness.add('a');
    await harness.add('b');
    await harness.add('c');
    await harness.add('d');

    harness.controller.moveQueuedTask(2, 0);

    expect(harness.queueVideoIds, ['d', 'b', 'c']);

    await _settle();

    expect(harness.queueRepository.saved[harness.taskIdOf('d')]?.position, 0);
    expect(harness.queueRepository.saved[harness.taskIdOf('c')]?.position, 2);
  });

  test('removeTask активной: загрузка останавливается, файлы удаляются, начинается следующая', () async {
    final harness = _Harness();

    await harness.add('a');
    await harness.add('b');

    final taskId = harness.taskIdOf('a');

    await harness.controller.removeTask(taskId);
    await _settle();

    expect(harness.downloads.first.isCancelled, isTrue);
    expect(harness.queueRepository.removedTaskIds, [taskId]);
    expect(harness.state.taskById(taskId), isNull);
    expect(harness.state.activeTask?.video.id, 'b');
    expect(harness.downloads.last.taskId, harness.taskIdOf('b'));
  });

  test('removeTask из очереди не трогает активную загрузку', () async {
    final harness = _Harness();

    await harness.add('a');
    await harness.add('b');
    await harness.add('c');

    await harness.controller.removeTask(harness.taskIdOf('b'));
    await _settle();

    expect(harness.downloads.single.isCancelled, isFalse);
    expect(harness.queueVideoIds, ['c']);
    expect(harness.state.queue.single.position, 0);
  });

  test('ошибка загрузки: видео остаётся в начале очереди с причиной и пропускается, повтор продолжает с тех же потоков', () async {
    final harness = _Harness();

    await harness.add('a');
    await harness.add('b');
    await harness.add('c');

    harness.downloads.first.selectStreams(_videoStreams);
    harness.downloads.first.failWith(
      const VideoFailure(code: 'unplayable', message: 'Войдите в аккаунт', needsSignIn: true),
    );
    await _settle();

    final failedTask = harness.state.queue.first;

    expect(harness.queueVideoIds, ['a', 'c']);
    expect(failedTask.status, DownloadTaskStatus.failed);
    expect(failedTask.failureMessage, 'Войдите в аккаунт');
    expect(failedTask.failureNeedsSignIn, isTrue);
    expect(harness.state.finished, isEmpty);
    expect(harness.state.activeTask?.video.id, 'b');

    /// "b" is done: "c" starts next, the failed "a" waits for a retry
    harness.downloads.last.succeed(r'C:\Downloads\b.mp4');
    await _settle();

    expect(harness.state.activeTask?.video.id, 'c');
    expect(harness.queueVideoIds, ['a']);

    await harness.controller.signInAndRetry(failedTask.id);
    await _settle();

    expect(harness.authenticationRepository.signInCalls, 1);
    expect(harness.state.queue.single.status, DownloadTaskStatus.queued);
    expect(harness.state.queue.single.failureMessage, isNull);

    harness.downloads.last.succeed(r'C:\Downloads\c.mp4');
    await _settle();

    expect(harness.downloads.last.taskId, failedTask.id);
    expect(harness.downloads.last.streams, _videoStreams);
  });

  test('без свободных видео в очереди неудачная загрузка сама не начинается', () async {
    final harness = _Harness();

    await harness.add('a');

    harness.downloads.single.failWith(const VideoFailure(code: 'mux', message: 'Не удалось собрать файл'));
    await _settle();

    expect(harness.state.activeTask, isNull);
    expect(harness.queueVideoIds, ['a']);
    expect(harness.downloads, hasLength(1));

    await harness.controller.startTask(harness.taskIdOf('a'));
    await _settle();

    expect(harness.state.activeTask?.status, DownloadTaskStatus.downloading);
    expect(harness.state.activeTask?.failureMessage, isNull);
    expect(harness.downloads, hasLength(2));
  });

  test('clearFinished очищает список скачанных вместе с копиями превью', () async {
    final harness = _Harness();

    await harness.add('a');

    harness.downloads.single.succeed(r'C:\Downloads\a.mp4');
    await _settle();

    final taskId = harness.taskIdOf('a');

    await harness.controller.clearFinished();
    await _settle();

    expect(harness.state.finished, isEmpty);
    expect(harness.queueRepository.removedTaskIds, [taskId]);
  });

  group('restoreQueue', () {
    test('загрузка, прерванная закрытием приложения, продолжается с сохранёнными потоками', () async {
      final harness = _Harness();

      harness.queueRepository.restoreResult = (
        failure: null,
        data: [
          _restoredTask(
            'a',
            status: DownloadTaskStatus.downloading,
            section: DownloadTaskSection.active,
            downloadedBytes: 640,
            streams: _videoStreams,
          ),
          _restoredTask('b', status: DownloadTaskStatus.queued, section: DownloadTaskSection.queue),
        ],
      );

      await harness.controller.restoreQueue();
      await _settle();

      expect(harness.state.isRestoring, isFalse);
      expect(harness.state.activeTask?.status, DownloadTaskStatus.downloading);
      expect(harness.state.activeTask?.downloadedBytes, 640);
      expect(harness.downloads.single.taskId, 'task-a');
      expect(harness.downloads.single.streams, _videoStreams);
      expect(harness.queueVideoIds, ['b']);
    });

    test('поставленная на паузу загрузка ждёт пользователя', () async {
      final harness = _Harness();

      harness.queueRepository.restoreResult = (
        failure: null,
        data: [
          _restoredTask(
            'a',
            status: DownloadTaskStatus.paused,
            section: DownloadTaskSection.active,
            downloadedBytes: 640,
            streams: _videoStreams,
          ),
          _restoredTask('b', status: DownloadTaskStatus.queued, section: DownloadTaskSection.queue),
        ],
      );

      await harness.controller.restoreQueue();
      await _settle();

      expect(harness.state.activeTask?.status, DownloadTaskStatus.paused);
      expect(harness.downloads, isEmpty);
      expect(harness.state.activeTask?.removalNeedsConfirmation, isTrue);
    });

    test('без активной загрузки начинается первое видео очереди', () async {
      final harness = _Harness();

      harness.queueRepository.restoreResult = (
        failure: null,
        data: [
          _restoredTask('b', status: DownloadTaskStatus.queued, section: DownloadTaskSection.queue, position: 1),
          _restoredTask('a', status: DownloadTaskStatus.paused, section: DownloadTaskSection.queue),
        ]..sort((a, b) => a.position.compareTo(b.position)),
      );

      await harness.controller.restoreQueue();
      await _settle();

      expect(harness.state.activeTask?.video.id, 'a');
      expect(harness.downloads.single.taskId, 'task-a');
      expect(harness.queueVideoIds, ['b']);
    });

    test('неудачные загрузки прежних версий из завершённых переезжают в очередь', () async {
      final harness = _Harness();

      harness.queueRepository.restoreResult = (
        failure: null,
        data: [
          _restoredTask('b', status: DownloadTaskStatus.queued, section: DownloadTaskSection.queue),
          _restoredTask('done', status: DownloadTaskStatus.done, section: DownloadTaskSection.finished),
          _restoredTask('failed', status: DownloadTaskStatus.failed, section: DownloadTaskSection.finished, position: 1),
        ],
      );

      await harness.controller.restoreQueue();
      await _settle();

      expect([for (final task in harness.state.finished) task.video.id], ['done']);
      expect(harness.state.activeTask?.video.id, 'b');
      expect(harness.queueVideoIds, ['failed']);
      expect(harness.state.queue.single.status, DownloadTaskStatus.failed);
    });

    test('ошибка чтения базы показывается на экране', () async {
      final harness = _Harness();
      const failure = DownloadQueueFailure(code: 'storage', message: 'База недоступна');

      harness.queueRepository.restoreResult = (failure: failure, data: null);

      await harness.controller.restoreQueue();
      await _settle();

      expect(harness.state.failure, failure);
      expect(harness.state.isRestoring, isFalse);
    });
  });
}
