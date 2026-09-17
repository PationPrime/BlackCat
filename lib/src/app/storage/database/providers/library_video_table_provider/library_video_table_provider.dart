import 'package:drift/drift.dart';

import '../../../../dto/dto.dart';
import '../../database.dart';
import '../../tables/tables.dart';

/// Player library: videos of the download folder and their watch positions
final class LibraryVideoTableProvider {
  final AppDatabase databaseInstance;

  TableInfo<Table, LibraryVideosTableData>? libraryVideosTable;

  LibraryVideoTableProvider({required this.databaseInstance}) {
    libraryVideosTable =
        databaseInstance.tableMap[TableNames.libraryVideosTable]
            as TableInfo<Table, LibraryVideosTableData>?;
  }

  void _requireTables() {
    if (libraryVideosTable != null) return;

    throw Exception('Table `${TableNames.libraryVideosTable}` not found');
  }

  LibraryVideosTableCompanion _videoCompanion(
    LibraryVideoDto video,
    DateTime now,
  ) => LibraryVideosTableCompanion.insert(
    id: video.id,
    path: video.path,
    title: video.title,
    sizeBytes: video.sizeBytes,
    modifiedAt: video.modifiedAt,
    durationMs: Value(video.durationMs),
    positionMs: Value(video.positionMs),
    thumbnailPath: Value(video.thumbnailPath),
    isMetadataLoaded: Value(video.isMetadataLoaded),
    watchedAt: Value(video.watchedAt),
    createdAt: now,
    updatedAt: now,
  );

  LibraryVideoDto _videoDto(LibraryVideosTableData videoData) =>
      LibraryVideoDto(
        id: videoData.id,
        path: videoData.path,
        title: videoData.title,
        sizeBytes: videoData.sizeBytes,
        modifiedAt: videoData.modifiedAt,
        durationMs: videoData.durationMs,
        positionMs: videoData.positionMs,
        thumbnailPath: videoData.thumbnailPath,
        isMetadataLoaded: videoData.isMetadataLoaded,
        watchedAt: videoData.watchedAt,
      );

  Future<List<LibraryVideoDto>> getVideos() async {
    try {
      _requireTables();

      return [
        for (final videoData in await databaseInstance.readRecords(
          libraryVideosTable!,
        ))
          _videoDto(videoData),
      ];
    } catch (_) {
      rethrow;
    }
  }

  /// Creates new videos and overwrites existing ones. The time a video
  /// first appeared stays as it was
  Future<void> saveVideos(List<LibraryVideoDto> videos) async {
    try {
      _requireTables();

      if (videos.isEmpty) return;

      final now = DateTime.now();

      await databaseInstance.batch((batch) {
        for (final video in videos) {
          batch.insert(
            libraryVideosTable!,
            _videoCompanion(video, now),
            onConflict: DoUpdate(
              (_) => _videoCompanion(
                video,
                now,
              ).copyWith(createdAt: const Value.absent()),
            ),
          );
        }
      });
    } catch (_) {
      rethrow;
    }
  }

  /// Watch position: written often, so it touches only the playback fields
  Future<void> updatePosition({
    required String videoId,
    required int positionMs,
    required DateTime watchedAt,
    int? durationMs,
  }) async {
    try {
      _requireTables();

      await databaseInstance.updateRecord(
        libraryVideosTable!,
        LibraryVideosTableCompanion(
          positionMs: Value(positionMs),
          durationMs: durationMs == null
              ? const Value.absent()
              : Value(durationMs),
          watchedAt: Value(watchedAt),
          updatedAt: Value(DateTime.now()),
        ),
        (tbl) => tbl.id.equals(videoId),
      );
    } catch (_) {
      rethrow;
    }
  }

  /// What the system reported about the file: touches only these fields,
  /// so a watch position saved meanwhile stays
  Future<void> updateMetadata({
    required String videoId,
    required int? durationMs,
    required String? thumbnailPath,
  }) async {
    try {
      _requireTables();

      await databaseInstance.updateRecord(
        libraryVideosTable!,
        LibraryVideosTableCompanion(
          durationMs: Value(durationMs),
          thumbnailPath: Value(thumbnailPath),
          isMetadataLoaded: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
        (tbl) => tbl.id.equals(videoId),
      );
    } catch (_) {
      rethrow;
    }
  }

  Future<void> deleteVideos(List<String> videoIds) async {
    try {
      _requireTables();

      if (videoIds.isEmpty) return;

      await databaseInstance.deleteRecordWhere(
        libraryVideosTable!,
        (tbl) => tbl.id.isIn(videoIds),
      );
    } catch (_) {
      rethrow;
    }
  }
}
