import 'package:drift/drift.dart';

import '../../../../dto/dto.dart';
import '../../database.dart';
import '../../tables/tables.dart';

/// Download queue: downloads and the streams selected for them
final class DownloadTaskTableProvider {
  final AppDatabase databaseInstance;

  TableInfo<Table, DownloadTasksTableData>? downloadTasksTable;
  TableInfo<Table, DownloadTaskStreamsTableData>? downloadTaskStreamsTable;

  DownloadTaskTableProvider({required this.databaseInstance}) {
    downloadTasksTable =
        databaseInstance.tableMap[TableNames.downloadTasksTable]
            as TableInfo<Table, DownloadTasksTableData>?;

    downloadTaskStreamsTable =
        databaseInstance.tableMap[TableNames.downloadTaskStreamsTable]
            as TableInfo<Table, DownloadTaskStreamsTableData>?;
  }

  void _requireTables() {
    final missedTables = <String>[
      if (downloadTasksTable == null) TableNames.downloadTasksTable,
      if (downloadTaskStreamsTable == null) TableNames.downloadTaskStreamsTable,
    ];

    if (missedTables.isEmpty) return;

    throw Exception('Tables `${missedTables.join('`, `')}` not found');
  }

  DownloadTasksTableCompanion _taskCompanion(DownloadTaskDto task) =>
      DownloadTasksTableCompanion.insert(
        id: task.id,
        videoId: task.videoId,
        videoUrl: task.videoUrl,
        title: task.title,
        channel: Value(task.channel),
        durationSeconds: Value(task.durationSeconds),
        thumbnail: Value(task.thumbnail),
        viewCount: Value(task.viewCount),
        qualityId: task.qualityId,
        qualityKind: task.qualityKind,
        qualityLabel: Value(task.qualityLabel),
        qualityResolution: Value(task.qualityResolution),
        qualitySize: Value(task.qualitySize),
        qualityIsAac: Value(task.qualityIsAac),
        status: task.status,
        section: task.section,
        position: Value(task.position),
        downloadedBytes: Value(task.downloadedBytes),
        totalBytes: Value(task.totalBytes),
        filePath: Value(task.filePath),
        fileSizeBytes: Value(task.fileSizeBytes),
        thumbnailPath: Value(task.thumbnailPath),
        completedAt: Value(task.completedAt),
        failureMessage: Value(task.failureMessage),
        failureNeedsSignIn: Value(task.failureNeedsSignIn),
        createdAt: task.createdAt,
        updatedAt: task.updatedAt,
      );

  DownloadTaskDto _taskDto(
    DownloadTasksTableData taskData,
    Iterable<DownloadTaskStreamsTableData> streamsData,
  ) => DownloadTaskDto(
    id: taskData.id,
    videoId: taskData.videoId,
    videoUrl: taskData.videoUrl,
    title: taskData.title,
    channel: taskData.channel,
    durationSeconds: taskData.durationSeconds,
    thumbnail: taskData.thumbnail,
    viewCount: taskData.viewCount,
    qualityId: taskData.qualityId,
    qualityKind: taskData.qualityKind,
    qualityLabel: taskData.qualityLabel,
    qualityResolution: taskData.qualityResolution,
    qualitySize: taskData.qualitySize,
    qualityIsAac: taskData.qualityIsAac,
    status: taskData.status,
    section: taskData.section,
    position: taskData.position,
    downloadedBytes: taskData.downloadedBytes,
    totalBytes: taskData.totalBytes,
    filePath: taskData.filePath,
    fileSizeBytes: taskData.fileSizeBytes,
    thumbnailPath: taskData.thumbnailPath,
    completedAt: taskData.completedAt,
    failureMessage: taskData.failureMessage,
    failureNeedsSignIn: taskData.failureNeedsSignIn,
    createdAt: taskData.createdAt,
    updatedAt: taskData.updatedAt,
    streams: [
      for (final streamData in streamsData)
        DownloadStreamDto(
          role: streamData.role,
          itag: streamData.itag,
          contentLength: streamData.contentLength,
        ),
    ]..sort((a, b) => a.role.index.compareTo(b.role.index)),
  );

  /// All downloads by section and position within it
  Future<List<DownloadTaskDto>> getTasks() async {
    try {
      _requireTables();

      final tasksData = await databaseInstance.readRecords(
        downloadTasksTable!,
      );

      final streamsData = await databaseInstance.readRecords(
        downloadTaskStreamsTable!,
      );

      return [
        for (final taskData in tasksData)
          _taskDto(
            taskData,
            streamsData.where((stream) => stream.taskId == taskData.id),
          ),
      ]..sort(
        (a, b) => a.section.index != b.section.index
            ? a.section.index.compareTo(b.section.index)
            : a.position.compareTo(b.position),
      );
    } catch (_) {
      rethrow;
    }
  }

  /// Saves downloads in one transaction: creates new ones, overwrites
  /// existing ones together with their streams
  Future<void> saveTasks(List<DownloadTaskDto> tasks) async {
    try {
      _requireTables();

      if (tasks.isEmpty) return;

      await databaseInstance.transaction(() async {
        final taskIds = [for (final task in tasks) task.id];

        await databaseInstance.deleteRecordWhere(
          downloadTaskStreamsTable!,
          (tbl) => tbl.taskId.isIn(taskIds),
        );

        await databaseInstance.batch((batch) {
          batch.insertAllOnConflictUpdate(downloadTasksTable!, [
            for (final task in tasks) _taskCompanion(task),
          ]);

          batch.insertAll(downloadTaskStreamsTable!, [
            for (final task in tasks)
              for (final stream in task.streams)
                DownloadTaskStreamsTableCompanion.insert(
                  taskId: task.id,
                  role: stream.role,
                  itag: stream.itag,
                  contentLength: stream.contentLength,
                ),
          ]);
        });
      });
    } catch (_) {
      rethrow;
    }
  }

  /// Download progress: written often, so it touches only the byte counters
  Future<void> updateProgress({
    required String taskId,
    required int downloadedBytes,
    int? totalBytes,
  }) async {
    try {
      _requireTables();

      await databaseInstance.updateRecord(
        downloadTasksTable!,
        DownloadTasksTableCompanion(
          downloadedBytes: Value(downloadedBytes),
          totalBytes: totalBytes == null
              ? const Value.absent()
              : Value(totalBytes),
          updatedAt: Value(DateTime.now()),
        ),
        (tbl) => tbl.id.equals(taskId),
      );
    } catch (_) {
      rethrow;
    }
  }

  /// Deletes downloads. Streams are deleted by cascade via the foreign key
  Future<void> deleteTasks(List<String> taskIds) async {
    try {
      _requireTables();

      if (taskIds.isEmpty) return;

      await databaseInstance.deleteRecordWhere(
        downloadTasksTable!,
        (tbl) => tbl.id.isIn(taskIds),
      );
    } catch (_) {
      rethrow;
    }
  }

  Stream<List<DownloadTasksTableData>> watchTasks() {
    _requireTables();

    return databaseInstance.watchChanges(downloadTasksTable!);
  }
}
