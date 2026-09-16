part of 'download_queue_controller.dart';

class DownloadQueueState extends Equatable {
  /// The queue of previous launches is still being read from the database
  final bool isRestoring;

  /// The download that is running or paused in the "Active download"
  /// section. Only one video downloads at a time
  final DownloadTaskModel? activeTask;

  /// "Download queue" in order: the first video starts first
  final List<DownloadTaskModel> queue;

  /// "Download errors": failed downloads waiting for a retry, the most
  /// recent on top
  final List<DownloadTaskModel> failed;

  /// Downloaded videos, the most recent on top
  final List<DownloadTaskModel> finished;

  /// Error of the queue as a whole, e.g. saving to the database.
  /// Download errors are stored in the downloads themselves
  final Failure? failure;

  const DownloadQueueState({
    this.isRestoring = false,
    this.activeTask,
    this.queue = const [],
    this.failed = const [],
    this.finished = const [],
    this.failure,
  });

  List<DownloadTaskModel> get allTasks => [
    ?activeTask,
    ...queue,
    ...failed,
    ...finished,
  ];

  bool get hasActiveTask => activeTask != null;

  /// Signing out is not allowed while a video is downloading
  bool get hasRunningTask => activeTask?.isRunning ?? false;

  DownloadTaskModel? taskById(String taskId) =>
      allTasks.where((task) => task.id == taskId).firstOrNull;

  @override
  List<Object?> get props => [
    isRestoring,
    activeTask,
    queue,
    failed,
    finished,
    failure,
  ];

  DownloadQueueState copyWith({
    bool? isRestoring,
    DownloadTaskModel? activeTask,
    List<DownloadTaskModel>? queue,
    List<DownloadTaskModel>? failed,
    List<DownloadTaskModel>? finished,
    Failure? failure,
    bool clearActiveTask = false,
    bool clearFailure = false,
  }) => DownloadQueueState(
    isRestoring: isRestoring ?? this.isRestoring,
    activeTask: clearActiveTask ? null : activeTask ?? this.activeTask,
    queue: queue ?? this.queue,
    failed: failed ?? this.failed,
    finished: finished ?? this.finished,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}

final class DownloadQueueInitialState extends DownloadQueueState {
  const DownloadQueueInitialState();
}
