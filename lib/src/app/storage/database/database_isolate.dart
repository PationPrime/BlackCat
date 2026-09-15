part of 'database.dart';

class AppDatabaseIsolate extends Equatable {
  final DriftIsolate isolate;
  final DatabaseConnection connection;
  final AppDatabase database;

  const AppDatabaseIsolate({
    required this.isolate,
    required this.connection,
    required this.database,
  });

  @override
  List<Object?> get props => [isolate, connection, database];
}
