import 'dart:async';
import 'dart:math' as math;

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:youtube_downloader/src/app/constants/constants.dart';
import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/failure/failure.dart';
import 'package:youtube_downloader/src/app/logger/app_logger.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/operation_result/operation_result.dart';
import 'package:youtube_downloader/src/app/repositories/repositories.dart';
import 'package:youtube_downloader/src/app/shared_controllers/shared_controllers.dart';
import 'package:youtube_downloader/src/app/tools/tools.dart';

part 'download_queue_state.dart';
part 'download_run.dart';

/// Download queue: one active download, the queue behind it and downloaded videos.
///
/// Queue changes run strictly one at a time: pausing the active download
/// waits until it releases the unfinished files, and only then does the next
/// download start writing. Every change is saved to the database, so
/// the queue survives an app restart. Imported cookies retry the downloads
/// that failed for want of a sign-in
class DownloadQueueController extends Cubit<DownloadQueueState> {
  static const _appLogger = AppLogger(where: 'DownloadQueueController');

  /// Progress is written to the database no more often: after a sudden app close
  /// the exact bytes are taken from the length of the unfinished files anyway
  static const _progressSaveInterval = Duration(seconds: 2);

  /// A progress report without a speed keeps the last one this long:
  /// a new chunk of a stream starts without a speed, and the speed line
  /// would blink otherwise
  static const _speedHoldTime = Duration(seconds: 5);

  final DownloadQueueRepositoryInterface _downloadQueueRepository;
  final VideoRepositoryInterface _videoRepository;
  final YtDlpVideoRepositoryInterface _ytDlpVideoRepository;
  final SettingsRepositoryInterface _settingsRepository;
  final AuthorizationController _authorizationController;

  final _random = math.Random();

  /// The download that is running now
  _DownloadRun? _run;

  /// Tail of the queue change chain
  Future<void> _pendingOperation = Future<void>.value();

  var _lastProgressSave = DateTime.fromMillisecondsSinceEpoch(0);

  /// Progress of the active download is shown no more often
  final Duration _progressUpdateInterval;

  late final StreamSubscription<AuthorizationState> _authorizationSubscription;
  AccountSessionModel? _session;

  DownloadQueueController({
    required this._downloadQueueRepository,
    required this._videoRepository,
    required this._ytDlpVideoRepository,
    required this._settingsRepository,
    required this._authorizationController,
    this._progressUpdateInterval = DownloadConstants.progressUpdateInterval,
  }) : super(const DownloadQueueInitialState()) {
    _session = _authorizationController.state.session;
    _authorizationSubscription = _authorizationController.stream.listen(
      _onAuthorizationChanged,
    );
  }

  void _safeEmit(DownloadQueueState state) {
    if (isClosed) return;

    emit(state);
  }

  @override
  Future<void> close() async {
    /// Not awaited: the cancel future belongs to the root zone and never
    /// completes inside fake async zones of widget tests
    unawaited(_authorizationSubscription.cancel());

    _run?.stop();
    _run = null;

    await super.close();
  }

  /// Reads the queue of the previous launch. A download interrupted by closing
  /// the app continues from the same place; a paused one
  /// waits for the user
  Future<void> restoreQueue() => _serialized(() async {
    _safeEmit(state.copyWith(isRestoring: true, clearFailure: true));

    final restoreResponse = await _downloadQueueRepository.restoreTasks();

    if (restoreResponse.isFailed) {
      _safeEmit(state.copyWith(isRestoring: false));
      _showFailure(restoreResponse.failure, 'Failed to restore download queue');

      return;
    }

    final tasks = restoreResponse.requireData;
    final activeTasks = tasks.where((task) => task.section.isActive).toList();
    final activeTask = activeTasks.firstOrNull;

    _emitTasks(
      activeTask: activeTask,
      queue: [
        /// Extra active downloads go to the start of the queue
        for (final task in activeTasks.skip(1)) _pausedTask(task),
        for (final task in tasks.where((task) => task.section.isQueue))
          if (!task.status.isFailed) task.isRunning ? _pausedTask(task) : task,
      ],

      /// Older versions kept failed downloads in the queue or among
      /// the finished ones
      failed: [
        for (final task in tasks)
          if (task.status.isFailed && !task.section.isActive) task,
      ],
      finished: [
        for (final task in tasks)
          if (task.section.isFinished && task.status.isDone) task,
      ],
    );

    _safeEmit(state.copyWith(isRestoring: false));

    if (activeTask != null && activeTask.isRunning) {
      await _startActiveTask();
    } else {
      await _saveTasks();
      await _promoteNext();
    }
  });

  /// Adds a video: straight to the active download if the slot is free,
  /// otherwise to the end of the queue. [engine] downloads it; the built-in
  /// downloader takes over if yt-dlp disappears.
  ///
  /// A video added again after its download failed is not a second copy:
  /// the failed download returns to the queue and continues from its bytes.
  /// A video added while its first copy is still waiting, downloading or
  /// downloaded is a deliberate second copy
  Future<void> addTask({
    required VideoInfoModel video,
    required QualityModel quality,
    DownloadEngineModel engine = DownloadEngineModel.fallback,
  }) => _serialized(() async {
    final now = DateTime.now();
    final storedVideo = VideoInfoModel(
      id: video.id,
      title: video.title,
      url: video.url,
      qualities: const [],
      channel: video.channel,
      duration: video.duration,
      thumbnail: video.thumbnail,
      viewCount: video.viewCount,
    );
    final failedCopy = state.failed
        .where(
          (task) => task.video.id == video.id && task.quality.id == quality.id,
        )
        .firstOrNull;

    final task = switch (failedCopy) {
      final failedCopy? => _retriedTask(
        failedCopy,
        now,
      ).copyWith(video: storedVideo, quality: quality, engine: engine),
      null => DownloadTaskModel(
        id: _newTaskId(now),
        video: storedVideo,
        quality: quality,
        engine: engine,
        status: DownloadTaskStatus.queued,
        section: DownloadTaskSection.queue,
        createdAt: now,
        updatedAt: now,
      ),
    };

    _emitTasks(
      activeTask: state.activeTask,
      queue: [...state.queue, task],
      failed: _failedWithout(task.id),
      finished: state.finished,
    );

    await _saveTasks();
    await _promoteNext();
  });

  /// Starts a queued or failed video now. The active download is paused
  /// at the start of the queue and later continues from the same place
  Future<void> startTask(String taskId) => _serialized(() async {
    final task = _waitingTask(taskId);
    final activeTask = state.activeTask;

    if (task == null) return;

    if (activeTask == null) {
      _emitTasks(
        activeTask: task,
        queue: _queueWithout(taskId),
        failed: _failedWithout(taskId),
        finished: state.finished,
      );

      await _startActiveTask();

      return;
    }

    /// Muxing video and audio cannot be interrupted: the selected video starts
    /// right after it
    if (activeTask.status.isProcessing) {
      _emitTasks(
        activeTask: activeTask,
        queue: [task, ..._queueWithout(taskId)],
        failed: _failedWithout(taskId),
        finished: state.finished,
      );

      await _saveTasks();

      return;
    }

    final stoppedTask = _stoppedTask(activeTask, await _stopRun());

    _emitTasks(
      activeTask: _waitingTask(taskId) ?? task,
      queue: [
        if (!stoppedTask.status.isDone && !stoppedTask.status.isFailed)
          stoppedTask,
        ..._queueWithout(taskId),
      ],
      failed: [
        if (stoppedTask.status.isFailed) stoppedTask,
        ..._failedWithout(taskId),
      ],
      finished: [if (stoppedTask.status.isDone) stoppedTask, ...state.finished],
    );

    if (stoppedTask.status.isDone) {
      unawaited(_saveThumbnail(stoppedTask));
    }

    await _startActiveTask();
  });

  /// Pauses the active download. It stays in the "Active download"
  /// section, the queue waits
  Future<void> pauseActiveTask() => _serialized(() async {
    final activeTask = state.activeTask;

    if (activeTask == null || !activeTask.status.isDownloading) return;

    final stoppedTask = _stoppedTask(activeTask, await _stopRun());

    if (stoppedTask.status.isPaused) {
      _safeEmit(state.copyWith(activeTask: stoppedTask));
      await _saveTasks();

      return;
    }

    await _moveActiveOut(stoppedTask);
  });

  Future<void> resumeActiveTask() => _serialized(() async {
    if (state.activeTask?.status.isPaused ?? false) {
      await _startActiveTask();
    }
  });

  /// Reorders a video in the queue. [newIndex]: the video position after reordering.
  ///
  /// The state changes immediately, bypassing the change chain: the list being
  /// dragged must update in the same frame
  void moveQueuedTask(int oldIndex, int newIndex) {
    final queue = [...state.queue];

    if (oldIndex < 0 || oldIndex >= queue.length) return;

    final task = queue.removeAt(oldIndex);
    queue.insert(newIndex.clamp(0, queue.length), task);

    _emitTasks(
      activeTask: state.activeTask,
      queue: queue,
      finished: state.finished,
    );

    unawaited(_serialized(_saveTasks));
  }

  /// Removes a video from any section. Unfinished files and the thumbnail copy
  /// are deleted from the device, a downloaded file stays in the download folder
  Future<void> removeTask(String taskId) => _serialized(() async {
    final task = state.taskById(taskId);

    if (task == null) return;

    if (task.section.isActive) {
      final stoppedTask = _stoppedTask(task, await _stopRun());

      /// The download managed to finish: the video is already in the download folder
      if (stoppedTask.status.isDone) {
        await _moveActiveOut(stoppedTask);

        return;
      }
    }

    _emitTasks(
      activeTask: state.activeTask?.id == taskId ? null : state.activeTask,
      queue: _queueWithout(taskId),
      failed: _failedWithout(taskId),
      finished: [
        for (final task in state.finished)
          if (task.id != taskId) task,
      ],
    );

    await _removeFromStorage([taskId]);
    await _saveTasks();
    await _promoteNext();
  });

  /// Retries a failed download from where it failed: it moves to the start
  /// of the queue and starts right away if the active download slot is free
  Future<void> retryTask(String taskId) =>
      _retryWhere((task) => task.id == taskId);

  /// Retries every download that failed for want of a YouTube sign-in
  Future<void> retrySignInFailures() =>
      _retryWhere((task) => task.failureNeedsSignIn);

  Future<void> _retryWhere(bool Function(DownloadTaskModel task) test) =>
      _serialized(() async {
        final retried = state.failed.where(test).toList();

        if (retried.isEmpty) return;

        final now = DateTime.now();

        _emitTasks(
          activeTask: state.activeTask,
          queue: [
            for (final task in retried) _retriedTask(task, now),
            ...state.queue,
          ],
          failed: [
            for (final task in state.failed)
              if (!retried.contains(task)) task,
          ],
          finished: state.finished,
        );

        await _saveTasks();
        await _promoteNext();
      });

  static DownloadTaskModel _retriedTask(DownloadTaskModel task, DateTime now) =>
      task.copyWith(
        status: DownloadTaskStatus.queued,
        clearFailure: true,
        updatedAt: now,
      );

  /// Cookies imported in the settings may lift the sign-in requirement.
  /// Signing in through the window retries the chosen download on its own
  void _onAuthorizationChanged(AuthorizationState authorizationState) {
    final previousSession = _session;
    final session = _session = authorizationState.session;

    if (session != null && session.isImported && session != previousSession) {
      unawaited(retrySignInFailures());
    }
  }

  /// Signing in to YouTube (or refreshing the sign-in) and retrying a failed download
  Future<void> signInAndRetry(String taskId) async {
    if (!await _authorizationController.signIn()) {
      return;
    }

    await retryTask(taskId);
  }

  /// Clears the downloaded list. The videos stay in the download folder,
  /// thumbnail copies are deleted
  Future<void> clearFinished() => _serialized(() async {
    final taskIds = [for (final task in state.finished) task.id];

    if (taskIds.isEmpty) return;

    _emitTasks(
      activeTask: state.activeTask,
      queue: state.queue,
      finished: const [],
    );

    await _removeFromStorage(taskIds);
  });

  /// An error from another controller to show on the screen
  void showFailure(Failure failure) {
    _safeEmit(state.copyWith(failure: failure));
  }

  void dismissFailure() {
    _safeEmit(state.copyWith(clearFailure: true));
  }

  Future<void> _serialized(Future<void> Function() operation) =>
      _pendingOperation = _pendingOperation.then((_) async {
        if (isClosed) return;

        try {
          await operation();
        } catch (error, stackTrace) {
          _appLogger.logError(
            'Download queue operation failed: $error',
            stackTrace: stackTrace,
          );
        }
      });

  VideoRepositoryInterface _videoRepositoryOf(DownloadEngineModel engine) =>
      switch (engine) {
        DownloadEngineModel.builtIn => _videoRepository,
        DownloadEngineModel.ytDlp => _ytDlpVideoRepository,
      };

  String _newTaskId(DateTime now) =>
      '${now.microsecondsSinceEpoch.toRadixString(36)}'
      '-${_random.nextInt(1 << 30).toRadixString(36)}';

  /// A queued video, or a failed one ready for a retry
  DownloadTaskModel? _waitingTask(String taskId) =>
      state.queue.where((task) => task.id == taskId).firstOrNull ??
      switch (state.failed.where((task) => task.id == taskId).firstOrNull) {
        final task? => _retriedTask(task, DateTime.now()),
        null => null,
      };

  List<DownloadTaskModel> _queueWithout(String taskId) => [
    for (final task in state.queue)
      if (task.id != taskId) task,
  ];

  List<DownloadTaskModel> _failedWithout(String taskId) => [
    for (final task in state.failed)
      if (task.id != taskId) task,
  ];

  /// Distributes downloads into sections and numbers their positions.
  /// Without [failed] the failed downloads stay as they are
  void _emitTasks({
    required DownloadTaskModel? activeTask,
    required List<DownloadTaskModel> queue,
    required List<DownloadTaskModel> finished,
    List<DownloadTaskModel>? failed,
  }) => _safeEmit(
    state.copyWith(
      activeTask: activeTask == null
          ? null
          : _placed([activeTask], DownloadTaskSection.active).single,
      clearActiveTask: activeTask == null,
      queue: _placed(queue, DownloadTaskSection.queue),
      failed: _placed(failed ?? state.failed, DownloadTaskSection.failed),
      finished: _placed(finished, DownloadTaskSection.finished),
    ),
  );

  static List<DownloadTaskModel> _placed(
    List<DownloadTaskModel> tasks,
    DownloadTaskSection section,
  ) => [
    for (final (index, task) in tasks.indexed)
      task.section == section && task.position == index
          ? task
          : task.copyWith(section: section, position: index),
  ];

  Future<void> _saveTasks() async {
    final saveResponse = await _downloadQueueRepository.saveTasks(
      state.allTasks,
    );

    if (saveResponse.isFailed) {
      _showFailure(saveResponse.failure, 'Failed to save download queue');
    }
  }

  Future<void> _removeFromStorage(List<String> taskIds) async {
    final removeResponse = await _downloadQueueRepository.removeTasks(taskIds);

    if (removeResponse.isFailed) {
      _showFailure(removeResponse.failure, 'Failed to remove downloads');
    }
  }

  void _showFailure(Failure? failure, String description) {
    final effectiveFailure = failure ?? const OtherFailure();

    _appLogger.logFailure(effectiveFailure, description);

    _safeEmit(state.copyWith(failure: effectiveFailure));
  }

  /// If the active download slot is free, starts the first queued video
  Future<void> _promoteNext() async {
    if (state.activeTask != null) return;

    final nextTask = state.queue.firstOrNull;

    if (nextTask == null) return;

    _emitTasks(
      activeTask: nextTask,
      queue: _queueWithout(nextTask.id),
      finished: state.finished,
    );

    await _startActiveTask();
  }

  /// Moves a download out of the active slot: a downloaded one to the top
  /// of the downloaded list, a failed one to the top of the errors,
  /// a stopped one to the start of the queue
  Future<void> _moveActiveOut(DownloadTaskModel task) async {
    final status = task.status;

    _emitTasks(
      activeTask: null,
      queue: [if (!status.isDone && !status.isFailed) task, ...state.queue],
      failed: [if (status.isFailed) task, ...state.failed],
      finished: [if (status.isDone) task, ...state.finished],
    );

    await _saveTasks();

    if (status.isDone) {
      unawaited(_saveThumbnail(task));
    }

    await _promoteNext();
  }

  /// Saves a local thumbnail copy of a downloaded video. The network request
  /// runs outside the change chain, so the next download does not wait for it
  Future<void> _saveThumbnail(DownloadTaskModel task) async {
    final thumbnailResponse = await _downloadQueueRepository.saveThumbnail(
      task,
    );

    if (thumbnailResponse.isFailed) {
      _appLogger.logFailure(
        thumbnailResponse.failure ?? const OtherFailure(),
        'Failed to save thumbnail',
      );

      return;
    }

    final thumbnailPath = thumbnailResponse.data;

    if (thumbnailPath == null) return;

    await _serialized(() async {
      /// Removed from the list while the thumbnail was loading:
      /// the orphaned copy is wiped on the next launch
      if (!state.finished.any((finished) => finished.id == task.id)) return;

      _emitTasks(
        activeTask: state.activeTask,
        queue: state.queue,
        finished: [
          for (final finished in state.finished)
            finished.id == task.id
                ? finished.copyWith(thumbnailPath: thumbnailPath)
                : finished,
        ],
      );

      await _saveTasks();
    });
  }

  /// Starts the download from the "Active download" section
  Future<void> _startActiveTask() async {
    final activeTask = state.activeTask;

    if (activeTask == null || _run != null) return;

    final task = activeTask.copyWith(
      status: DownloadTaskStatus.downloading,
      clearSpeed: true,
      clearFailure: true,
      updatedAt: DateTime.now(),
    );

    _safeEmit(state.copyWith(activeTask: task));

    await _saveTasks();

    final run = _DownloadRun(task.id);
    _run = run;
    _lastProgressSave = DateTime.now();

    unawaited(_execute(run, task));
  }

  Future<void> _execute(_DownloadRun run, DownloadTaskModel task) async {
    final directoryResponse = await _settingsRepository.getDownloadDirectory();

    if (directoryResponse.isFailed) {
      /// Without settings the video is saved to Downloads
      _showFailure(
        directoryResponse.failure,
        'Failed to read download directory',
      );
    }

    Future<OperationResult<DownloadedFileModel>> download(
      DownloadEngineModel engine,
      List<DownloadStreamModel> streams,
    ) => run.cancellation.isCancelled
        ? Future.value(
            fail(VideoFailure(code: const VideoErrorCodes().canceled)),
          )
        : _videoRepositoryOf(engine).downloadVideo(
            taskId: task.id,
            url: task.video.url,
            quality: task.quality.id,
            streams: streams,
            destinationDirectory: directoryResponse.data?.path,
            cancellation: run.cancellation,
            onStreamsSelected: (streams) => _onStreamsSelected(run, streams),
            onProgress: (progress) => _onProgress(run, progress),
          );

    var downloadResponse = await download(task.engine, task.streams);

    /// yt-dlp is gone: both engines keep unfinished streams the same way,
    /// so the built-in downloader continues from the same bytes
    if (task.engine == DownloadEngineModel.ytDlp &&
        downloadResponse.failure?.code ==
            const VideoErrorCodes().ytDlpNotFound &&
        !run.cancellation.isCancelled) {
      final streams = _onEngineChanged(run, DownloadEngineModel.builtIn);

      downloadResponse = await download(
        DownloadEngineModel.builtIn,
        streams ?? task.streams,
      );
    }

    run.complete(downloadResponse);

    /// A stopped download is handled by whoever stopped it
    if (run.cancellation.isCancelled) return;

    await _serialized(() => _finishRun(run, downloadResponse));
  }

  /// Stops the active download and waits until it releases the files
  Future<_StoppedRun?> _stopRun() async {
    final run = _run;

    if (run == null) return null;

    _run = null;

    final interrupted = !run.isCompleted;

    run.stop();

    return (result: await run.result, interrupted: interrupted);
  }

  /// The download after stopping: done if it managed to finish; failed
  /// if it failed before the stop; otherwise paused
  DownloadTaskModel _stoppedTask(DownloadTaskModel task, _StoppedRun? stopped) {
    if (stopped == null) {
      return task.isRunning ? _pausedTask(task) : task;
    }

    final result = stopped.result;

    if (result.isSuccess) {
      return _doneTask(task, result.requireData);
    }

    if (!stopped.interrupted) {
      return _failedTask(task, result.failure ?? const OtherFailure());
    }

    return _pausedTask(task);
  }

  DownloadTaskModel _pausedTask(DownloadTaskModel task) => task.copyWith(
    status: DownloadTaskStatus.paused,
    clearSpeed: true,
    updatedAt: DateTime.now(),
  );

  DownloadTaskModel _doneTask(
    DownloadTaskModel task,
    DownloadedFileModel file,
  ) {
    final now = DateTime.now();

    return task.copyWith(
      status: DownloadTaskStatus.done,
      filePath: file.path,
      fileSizeBytes: file.sizeBytes,
      completedAt: now,
      downloadedBytes: task.totalBytes ?? task.downloadedBytes,
      clearSpeed: true,
      clearFailure: true,
      updatedAt: now,
    );
  }

  DownloadTaskModel _failedTask(DownloadTaskModel task, Failure failure) =>
      task.copyWith(
        status: DownloadTaskStatus.failed,
        failureMessage: failure.message,
        failureNeedsSignIn: failure is VideoFailure && failure.needsSignIn,
        clearSpeed: true,
        updatedAt: DateTime.now(),
      );

  /// Streams yt-dlp selected so far: the built-in downloader continues them
  List<DownloadStreamModel>? _onEngineChanged(
    _DownloadRun run,
    DownloadEngineModel engine,
  ) {
    final activeTask = state.activeTask;

    if (_run != run || activeTask == null || activeTask.id != run.taskId) {
      return null;
    }

    _safeEmit(
      state.copyWith(
        activeTask: activeTask.copyWith(
          engine: engine,
          updatedAt: DateTime.now(),
        ),
      ),
    );

    unawaited(_serialized(_saveTasks));

    return activeTask.streams;
  }

  void _onStreamsSelected(_DownloadRun run, List<DownloadStreamModel> streams) {
    final activeTask = state.activeTask;

    if (_run != run || activeTask == null || activeTask.id != run.taskId) {
      return;
    }

    _safeEmit(
      state.copyWith(
        activeTask: activeTask.copyWith(
          streams: streams,
          totalBytes: streams.fold<int>(
            0,
            (sum, stream) => sum + stream.contentLength,
          ),
          updatedAt: DateTime.now(),
        ),
      ),
    );

    /// Streams are needed for resuming: they are saved right away
    unawaited(_serialized(_saveTasks));
  }

  /// Shows the progress at most once per [_progressUpdateInterval]:
  /// a report that comes sooner waits, and a newer one replaces it.
  /// A new stage (e.g. muxing) is shown right away
  void _onProgress(_DownloadRun run, DownloadProgressModel progress) {
    final activeTask = state.activeTask;

    if (_run != run || activeTask == null || activeTask.id != run.taskId) {
      return;
    }

    final status = _statusOf(progress);
    final now = DateTime.now();
    final sinceShown = now.difference(run.progressShownAt ?? DateTime(0));

    if (status == activeTask.status && sinceShown < _progressUpdateInterval) {
      run.deferProgress(
        progress,
        after: _progressUpdateInterval - sinceShown,
        onDue: (pending) => _showProgress(run, pending),
      );

      return;
    }

    run.cancelDeferredProgress();
    _showProgress(run, progress);
  }

  static DownloadTaskStatus _statusOf(DownloadProgressModel progress) =>
      progress.stage.isProcessing
      ? DownloadTaskStatus.processing
      : DownloadTaskStatus.downloading;

  void _showProgress(_DownloadRun run, DownloadProgressModel progress) {
    final activeTask = state.activeTask;

    if (_run != run || activeTask == null || activeTask.id != run.taskId) {
      return;
    }

    final status = _statusOf(progress);
    final now = DateTime.now();

    run.progressShownAt = now;

    var speed = progress.speed;
    var eta = progress.eta;

    if (speed != null) {
      run.speedReportedAt = now;
    } else if (activeTask.speed case final heldSpeed?
        when heldSpeed > 0 &&
            status == activeTask.status &&
            now.difference(run.speedReportedAt ?? now) < _speedHoldTime) {
      speed = heldSpeed;

      final downloadedBytes = progress.downloadedBytes;
      final totalBytes = progress.totalBytes;

      eta = downloadedBytes != null && totalBytes != null
          ? (totalBytes - downloadedBytes).clamp(0, totalBytes) / heldSpeed
          : activeTask.eta;
    }

    final task = activeTask
        .copyWith(clearSpeed: true)
        .copyWith(
          status: status,
          downloadedBytes: progress.downloadedBytes,
          totalBytes: progress.totalBytes,
          speed: speed,
          eta: eta,
        );

    _safeEmit(state.copyWith(activeTask: task));

    if (status != activeTask.status) {
      _lastProgressSave = now;
      unawaited(_serialized(_saveTasks));
    } else if (now.difference(_lastProgressSave) >= _progressSaveInterval) {
      _lastProgressSave = now;
      unawaited(
        _downloadQueueRepository.updateProgress(
          taskId: task.id,
          downloadedBytes: task.downloadedBytes,
          totalBytes: task.totalBytes,
        ),
      );
    }
  }

  Future<void> _finishRun(
    _DownloadRun run,
    OperationResult<DownloadedFileModel> downloadResponse,
  ) async {
    final activeTask = state.activeTask;

    if (_run != run || activeTask == null || activeTask.id != run.taskId) {
      return;
    }

    _run = null;
    run.cancelDeferredProgress();

    if (downloadResponse.isSuccess) {
      await _moveActiveOut(_doneTask(activeTask, downloadResponse.requireData));

      return;
    }

    final failure = downloadResponse.failure ?? const OtherFailure();

    _appLogger.logFailure(failure, 'Failed to download video');

    await _moveActiveOut(_failedTask(activeTask, failure));
  }
}
