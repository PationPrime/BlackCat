import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../constants/constants.dart';
import '../../logger/app_logger.dart';
import '../../models/models.dart';
import 'providers/providers.dart';
import 'tables/tables.dart';

part 'database_isolate.dart';
part 'database.g.dart';

@DriftDatabase(tables: [DownloadTasksTable, DownloadTaskStreamsTable])
class AppDatabase extends _$AppDatabase implements DatabaseProvider {
  static const _appLogger = AppLogger(where: 'AppDatabase');

  AppDatabase(super.executor);

  static Future<File> _databaseFile() async {
    final dir = await getApplicationSupportDirectory();

    return File(p.join(dir.path, StorageConstants.databaseFileName));
  }

  static Future<DriftIsolate> createDriftIsolate() async {
    final dbFile = await _databaseFile();

    return await DriftIsolate.spawn(
      () => NativeDatabase(
        dbFile,
        setup: (db) => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
  }

  static Future<AppDatabaseIsolate> connectIsolateDatabase() async {
    final isolate = await createDriftIsolate();
    final connection = await isolate.connect();

    return AppDatabaseIsolate(
      isolate: isolate,
      connection: connection,
      database: AppDatabase(connection),
    );
  }

  AppDatabase.forTesting(DatabaseConnection super.connection);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async => await migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      /// The downloaded list got the file size, completion time
      /// and a local thumbnail copy
      if (from < 2) {
        await migrator.addColumn(
          downloadTasksTable,
          downloadTasksTable.fileSizeBytes,
        );
        await migrator.addColumn(
          downloadTasksTable,
          downloadTasksTable.thumbnailPath,
        );
        await migrator.addColumn(
          downloadTasksTable,
          downloadTasksTable.completedAt,
        );
      }
    },
    beforeOpen: (_) async => await customStatement('PRAGMA foreign_keys = ON'),
  );

  @override
  Map<String, TableInfo<Table, dynamic>> get tableMap => {
    TableNames.downloadTasksTable: downloadTasksTable,
    TableNames.downloadTaskStreamsTable: downloadTaskStreamsTable,
  };

  @override
  Future<void> clearAllTables() async {
    /// Order matters: streams are deleted before their downloads
    final List<TableInfo<Table, dynamic>> allTables = [
      downloadTaskStreamsTable,
      downloadTasksTable,
    ];

    for (final table in allTables) {
      await delete(table).go();
    }
  }

  @override
  Future<void> resetDatabase() async {
    final dbFile = await _databaseFile();

    _appLogger.logMessage('Deleting database at: ${dbFile.path}');

    if (await dbFile.exists()) {
      await dbFile.delete();
      _appLogger.logMessage('DB file deleted');
    } else {
      _appLogger.logMessage('DB file not found');
    }
  }

  @override
  Future<int> createRecord<D extends Insertable<D>>(
    TableInfo<Table, D> table,
    D entity, {
    bool updateOnConflict = false,
  }) async => updateOnConflict
      ? await into(table).insertOnConflictUpdate(entity)
      : await into(table).insert(entity);

  @override
  Future<List<D>> readRecords<D extends Insertable<D>>(
    TableInfo<Table, D> table, {
    Expression<bool> Function(dynamic tbl)? whereClause,
  }) async => whereClause == null
      ? await select(table).get()
      : await (select(table)..where(whereClause)).get();

  @override
  Future<List<D>> readRecordsOrderBy<D extends Insertable<D>>(
    TableInfo<Table, D> table, {
    Expression<bool> Function(dynamic tbl)? whereClause,
    List<OrderingTerm Function(Table)> orderByClauses = const [],
  }) async => whereClause == null
      ? await (select(table)..orderBy(orderByClauses)).get()
      : await (select(table)
              ..where(whereClause)
              ..orderBy(orderByClauses))
            .get();

  @override
  Future<List<D>> readRecordWhere<D extends Insertable<D>>(
    TableInfo<Table, D> table,
    Expression<bool> Function(dynamic tbl) whereClause,
  ) async => (select(table)..where(whereClause)).get();

  @override
  Future<void> updateRecord<D extends Insertable<D>>(
    TableInfo<Table, D> table,
    D entity,
    Expression<bool> Function(dynamic tbl) whereClause,
  ) async => await (update(table)..where(whereClause)).write(entity);

  @override
  Future<void> updateOrCreateRecord<D extends Insertable<D>>(
    TableInfo<Table, D> table,
    D entity,
    Expression<bool> Function(dynamic tbl) whereClause,
  ) async {
    final currentResults = await (select(table)..where(whereClause)).get();

    if (currentResults.isEmpty) {
      await into(table).insert(entity);
    } else {
      await (update(table)..where(whereClause)).write(entity);
    }
  }

  @override
  Future<void> deleteRecord<D extends Insertable<D>>(
    TableInfo<Table, D> table,
    D entity,
  ) async => await delete(table).delete(entity);

  @override
  Future<void> deleteRecordWhere<D extends Insertable<D>>(
    TableInfo<Table, D> table,
    Expression<bool> Function(dynamic tbl) whereClause,
  ) async => await (delete(table)..where(whereClause)).go();

  @override
  Stream<List<D>> watchChanges<D extends Insertable<D>>(
    TableInfo<Table, D> table,
  ) => (select(table)).watch();

  @override
  Future<void> deleteAllRecords<D extends Insertable<D>>(
    TableInfo<Table, D> table,
  ) async => await delete(table).go();

  @override
  Future<D?> readRecord<D>(
    TableInfo<Table, D> table, {
    Expression<bool> Function(dynamic tbl)? whereClause,
  }) async => whereClause == null
      ? await select(table).watchSingleOrNull().first
      : await (select(table)..where(whereClause)).getSingleOrNull();

  @override
  Future<bool> exists<D extends Insertable<D>>(
    TableInfo<Table, D> table,
    Expression<bool> Function(dynamic tbl) whereClause,
  ) async {
    final result = await (select(table)..where(whereClause)).getSingleOrNull();

    return result != null;
  }
}
