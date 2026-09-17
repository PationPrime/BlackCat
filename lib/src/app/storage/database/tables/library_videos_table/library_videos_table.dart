import 'package:drift/drift.dart';

/// Videos of the download folder shown in the player: where the user stopped
/// watching, the duration and the local thumbnail.
///
/// A row lives while its file is in the download folder
class LibraryVideosTable extends Table {
  /// Derived from the file path
  TextColumn get id => text()();
  TextColumn get path => text()();
  TextColumn get title => text()();
  IntColumn get sizeBytes => integer()();
  DateTimeColumn get modifiedAt => dateTime()();
  IntColumn get durationMs => integer().nullable()();

  /// Where the user stopped watching
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  TextColumn get thumbnailPath => text().nullable()();

  /// The system has been asked for the thumbnail and duration
  BoolColumn get isMetadataLoaded =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get watchedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
