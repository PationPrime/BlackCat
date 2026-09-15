import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/src/app/dto/dto.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/storage/database/database.dart';
import 'package:youtube_downloader/src/app/storage/database/providers/providers.dart';

/// Schema version 1 exactly as drift created it before the downloaded list
const _schemaV1 = [
  'CREATE TABLE "download_tasks_table" ("id" TEXT NOT NULL, "video_id" TEXT NOT NULL, "video_url" TEXT NOT NULL, '
      '"title" TEXT NOT NULL, "channel" TEXT NULL, "duration_seconds" REAL NULL, "thumbnail" TEXT NULL, '
      '"view_count" INTEGER NULL, "quality_id" TEXT NOT NULL, "quality_kind" TEXT NOT NULL, '
      '"quality_label" TEXT NOT NULL DEFAULT \'\', "quality_resolution" INTEGER NULL, "quality_size" INTEGER NULL, '
      '"quality_is_aac" INTEGER NOT NULL DEFAULT 0 CHECK ("quality_is_aac" IN (0, 1)), "status" TEXT NOT NULL, '
      '"section" TEXT NOT NULL, "position" INTEGER NOT NULL DEFAULT 0, "downloaded_bytes" INTEGER NOT NULL DEFAULT 0, '
      '"total_bytes" INTEGER NULL, "file_path" TEXT NULL, "failure_message" TEXT NULL, '
      '"failure_needs_sign_in" INTEGER NOT NULL DEFAULT 0 CHECK ("failure_needs_sign_in" IN (0, 1)), '
      '"created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "download_task_streams_table" ("task_id" TEXT NOT NULL REFERENCES download_tasks_table (id) '
      'ON DELETE CASCADE, "role" TEXT NOT NULL, "itag" INTEGER NOT NULL, "content_length" INTEGER NOT NULL, '
      'PRIMARY KEY ("task_id", "role"))',
];

void main() {
  test('миграция с версии 1 сохраняет загрузки и добавляет поля скачанного видео', () async {
    final database = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(
          setup: (db) {
            _schemaV1.forEach(db.execute);
            db.execute(
              'INSERT INTO download_tasks_table (id, video_id, video_url, title, quality_id, quality_kind, '
              'status, section, file_path, created_at, updated_at) VALUES '
              "('a', 'video-a', 'https://youtu.be/video-a', 'Видео a', '1080', 'video', 'done', 'finished', "
              r"'C:\Downloads\a.mp4', 1788000000, 1788000000)",
            );
            db.execute("INSERT INTO download_task_streams_table VALUES ('a', 'audio', 140, 1000)");
            db.execute('PRAGMA user_version = 1');
          },
        ),
      ),
    );

    final provider = DownloadTaskTableProvider(databaseInstance: database);
    final task = (await provider.getTasks()).single;

    expect(task.status, DownloadTaskStatus.done);
    expect(task.filePath, r'C:\Downloads\a.mp4');
    expect(task.streams.single.itag, 140);
    expect(task.fileSizeBytes, isNull);
    expect(task.thumbnailPath, isNull);
    expect(task.completedAt, isNull);

    await provider.saveTasks([
      DownloadTaskDto.fromModel(
        task.toModel().copyWith(fileSizeBytes: 2048, thumbnailPath: r'C:\Thumbnails\a.jpg'),
      ),
    ]);

    final migrated = (await provider.getTasks()).single;

    expect(migrated.fileSizeBytes, 2048);
    expect(migrated.thumbnailPath, r'C:\Thumbnails\a.jpg');

    await database.close();
  });
}
