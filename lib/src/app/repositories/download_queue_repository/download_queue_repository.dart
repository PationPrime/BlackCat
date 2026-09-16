import 'package:path/path.dart' as p;

import '../../data_sources/data_sources.dart';
import '../../dto/dto.dart';
import '../../errors/errors.dart';
import '../../failure/failure.dart';
import '../../models/models.dart';
import '../../operation_result/operation_result.dart';
import '../../services/services.dart';
import '../../storage/database/providers/providers.dart';
import '../../tools/tools.dart';
import 'download_queue_repository_interface.dart';

final class DownloadQueueRepository
    implements DownloadQueueRepositoryInterface {
  static const _defaultThumbnailExtension = 'jpg';
  static const _thumbnailExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  final DownloadTaskTableProvider _downloadTaskTableProvider;
  final RemoteThumbnailDataSource _remoteThumbnailDataSource;
  final FileSystemService _fileSystemService;

  const DownloadQueueRepository({
    required this._downloadTaskTableProvider,
    required this._remoteThumbnailDataSource,
    required this._fileSystemService,
  });

  @override
  ErrorHandler<DownloadQueueErrorCodes> get errorHandler =>
      const DownloadQueueErrorHandler();

  Failure _storageFailure(Object error, StackTrace stackTrace) =>
      errorHandler.handleError(
        DownloadQueueException(
          const DownloadQueueErrorCodes().storage,
          cause: error,
        ),
        stackTrace: stackTrace,
      );

  @override
  Future<OperationResult<List<DownloadTaskModel>>> restoreTasks() async {
    try {
      final tasks = [
        for (final task in await _downloadTaskTableProvider.getTasks())
          task.toModel(),
      ];

      /// Finished downloads do not need a work folder; failed ones keep
      /// their downloaded bytes so a retry continues from where it failed
      await _fileSystemService.deleteDownloadWorkDirectoriesExcept({
        for (final task in tasks)
          if (!task.status.isDone) task.id,
      });

      await _fileSystemService.deleteThumbnailsExcept({
        for (final task in tasks) task.id,
      });

      return ok([for (final task in tasks) await _withDownloadedBytes(task)]);
    } catch (error, stackTrace) {
      return fail(_storageFailure(error, stackTrace));
    }
  }

  /// Downloaded bytes: length of the unfinished files of the selected streams
  Future<DownloadTaskModel> _withDownloadedBytes(DownloadTaskModel task) async {
    if (task.status.isDone) return task;

    if (task.streams.isEmpty) {
      return task.copyWith(downloadedBytes: 0);
    }

    final workDirectory = await _fileSystemService.downloadWorkDirectory(
      task.id,
    );
    var downloadedBytes = 0;

    for (final stream in task.streams) {
      final partPath = DownloadPartFiles.path(workDirectory.path, stream);
      final partLength = await _fileSystemService.fileLength(partPath);

      /// yt-dlp names a finished stream without `.part` until the app
      /// renames it back
      final length = partLength > 0
          ? partLength
          : await _fileSystemService.fileLength(p.withoutExtension(partPath));

      downloadedBytes += DownloadPartFiles.resumableBytes(length, stream);
    }

    return task.copyWith(
      downloadedBytes: downloadedBytes,
      totalBytes: task.streams.fold<int>(
        0,
        (sum, stream) => sum + stream.contentLength,
      ),
    );
  }

  @override
  Future<OperationResult<void>> saveTasks(List<DownloadTaskModel> tasks) async {
    try {
      await _downloadTaskTableProvider.saveTasks([
        for (final task in tasks) DownloadTaskDto.fromModel(task),
      ]);

      return ok(null);
    } catch (error, stackTrace) {
      return fail(_storageFailure(error, stackTrace));
    }
  }

  @override
  Future<OperationResult<void>> updateProgress({
    required String taskId,
    required int downloadedBytes,
    int? totalBytes,
  }) async {
    try {
      await _downloadTaskTableProvider.updateProgress(
        taskId: taskId,
        downloadedBytes: downloadedBytes,
        totalBytes: totalBytes,
      );

      return ok(null);
    } catch (error, stackTrace) {
      return fail(_storageFailure(error, stackTrace));
    }
  }

  @override
  Future<OperationResult<void>> removeTasks(List<String> taskIds) async {
    try {
      await _downloadTaskTableProvider.deleteTasks(taskIds);

      for (final taskId in taskIds) {
        await _fileSystemService.deleteDownloadWorkDirectory(taskId);
      }

      await _fileSystemService.deleteThumbnails(taskIds.toSet());

      return ok(null);
    } catch (error, stackTrace) {
      return fail(_storageFailure(error, stackTrace));
    }
  }

  @override
  Future<OperationResult<String?>> saveThumbnail(DownloadTaskModel task) async {
    final url = task.video.thumbnail;

    if (url == null) return ok(null);

    try {
      final bytes = await _remoteThumbnailDataSource.getThumbnail(url);

      if (bytes.isEmpty) return ok(null);

      final path = await _fileSystemService.thumbnailPath(
        task.id,
        extension: _thumbnailExtensionOf(url),
      );

      await _fileSystemService.writeFile(path, bytes);

      return ok(path);
    } catch (error, stackTrace) {
      return fail(errorHandler.handleError(error, stackTrace: stackTrace));
    }
  }

  /// `maxresdefault.jpg`, `hqdefault.webp`…: the format is in the link path
  static String _thumbnailExtensionOf(String url) {
    final extension = p
        .extension(Uri.tryParse(url)?.path ?? '')
        .replaceFirst('.', '')
        .toLowerCase();

    return _thumbnailExtensions.contains(extension)
        ? extension
        : _defaultThumbnailExtension;
  }
}