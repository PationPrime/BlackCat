import 'package:drift/drift.dart';

import '../../../../models/models.dart';

/// A download in the queue: video, selected quality, section, position and progress.
///
/// Enums are stored by value name: renaming a value
/// requires a migration
class DownloadTasksTable extends Table {
  TextColumn get id => text()();

  TextColumn get videoId => text()();
  TextColumn get videoUrl => text()();
  TextColumn get title => text()();
  TextColumn get channel => text().nullable()();
  RealColumn get durationSeconds => real().nullable()();
  TextColumn get thumbnail => text().nullable()();
  IntColumn get viewCount => integer().nullable()();

  TextColumn get qualityId => text()();
  TextColumn get qualityKind => textEnum<QualityKind>()();
  TextColumn get qualityLabel => text().withDefault(const Constant(''))();
  IntColumn get qualityResolution => integer().nullable()();

  /// Approximate file size from the quality list
  IntColumn get qualitySize => integer().nullable()();
  BoolColumn get qualityIsAac => boolean().withDefault(const Constant(false))();

  TextColumn get status => textEnum<DownloadTaskStatus>()();
  TextColumn get section => textEnum<DownloadTaskSection>()();

  /// Downloads of older versions were all built-in
  TextColumn get engine => textEnum<DownloadEngineModel>().withDefault(
    Constant(DownloadEngineModel.builtIn.name),
  )();
  IntColumn get position => integer().withDefault(const Constant(0))();

  /// Downloaded bytes as of the last save. On app launch it is checked
  /// against the length of the unfinished files
  IntColumn get downloadedBytes => integer().withDefault(const Constant(0))();
  IntColumn get totalBytes => integer().nullable()();

  TextColumn get filePath => text().nullable()();

  /// Size of the finished file in bytes
  IntColumn get fileSizeBytes => integer().nullable()();

  /// Local copy of the thumbnail in the app folder
  TextColumn get thumbnailPath => text().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  TextColumn get failureMessage => text().nullable()();
  BoolColumn get failureNeedsSignIn =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
