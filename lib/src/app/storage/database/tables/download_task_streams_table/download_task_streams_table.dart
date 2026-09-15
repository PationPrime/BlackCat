import 'package:drift/drift.dart';

import '../../../../models/models.dart';
import '../download_tasks_table/download_tasks_table.dart';

/// Streams selected for a download: the download continues from the same place
/// using them after a pause and an app restart.
///
/// Unfinished bytes lie in the download work folder in
/// `<role>-<itag>-<size>.part` files
class DownloadTaskStreamsTable extends Table {
  TextColumn get taskId => text().references(
    DownloadTasksTable,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get role => textEnum<DownloadStreamRole>()();
  IntColumn get itag => integer()();
  IntColumn get contentLength => integer()();

  @override
  Set<Column> get primaryKey => {taskId, role};
}
