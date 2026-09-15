import 'package:drift/drift.dart';

abstract interface class DatabaseProvider {
  Map<String, TableInfo<Table, dynamic>> get tableMap;

  Future<void> clearAllTables();

  Future<void> resetDatabase();

  Future<int> createRecord<D extends Insertable<D>>(
    TableInfo<Table, D> table,
    D entity, {
    bool updateOnConflict = false,
  });

  Future<List<D>> readRecords<D extends Insertable<D>>(
    TableInfo<Table, D> table, {
    Expression<bool> Function(dynamic tbl)? whereClause,
  });

  Future<List<D>> readRecordsOrderBy<D extends Insertable<D>>(
    TableInfo<Table, D> table, {
    Expression<bool> Function(dynamic tbl)? whereClause,
    List<OrderingTerm Function(Table)> orderByClauses = const [],
  });

  Future<D?> readRecord<D>(
    TableInfo<Table, D> table, {
    Expression<bool> Function(dynamic tbl)? whereClause,
  });

  Future<List<D>> readRecordWhere<D extends Insertable<D>>(
    TableInfo<Table, D> table,
    Expression<bool> Function(dynamic tbl) whereClause,
  );

  Future<void> updateRecord<D extends Insertable<D>>(
    TableInfo<Table, D> table,
    D entity,
    Expression<bool> Function(dynamic tbl) whereClause,
  );

  Future<void> updateOrCreateRecord<D extends Insertable<D>>(
    TableInfo<Table, D> table,
    D entity,
    Expression<bool> Function(dynamic tbl) whereClause,
  );

  Future<void> deleteRecord<D extends Insertable<D>>(
    TableInfo<Table, D> table,
    D entity,
  );

  Future<void> deleteRecordWhere<D extends Insertable<D>>(
    TableInfo<Table, D> table,
    Expression<bool> Function(dynamic tbl) whereClause,
  );

  Stream<List<D>> watchChanges<D extends Insertable<D>>(
    TableInfo<Table, D> table,
  );

  Future<void> deleteAllRecords<D extends Insertable<D>>(
    TableInfo<Table, D> table,
  );

  Future<bool> exists<D extends Insertable<D>>(
    TableInfo<Table, D> table,
    Expression<bool> Function(dynamic tbl) whereClause,
  );
}
