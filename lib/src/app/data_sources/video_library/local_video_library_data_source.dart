import 'dart:io';

import 'package:path/path.dart' as p;

import '../../constants/constants.dart';
import '../../models/models.dart';
import '../../services/services.dart';

/// Video files of the download folder and thumbnails of the player library
abstract interface class LocalVideoLibraryDataSource {
  Future<bool> folderExists(String folder);

  /// Video files right in [folder], without subfolders
  Future<List<LocalVideoFileModel>> getVideoFiles(String folder);

  /// Emits when a video file in [folder] appears, changes or disappears
  Stream<void> watchFolder(String folder);

  Future<bool> fileExists(String path);

  /// Copies [from] to [to], replacing an existing file
  Future<void> copyFile(String from, String to);

  /// Path of a library thumbnail. [version] tells apart thumbnails of
  /// a replaced file, so the screen does not show the cached old one
  Future<String> thumbnailPath(
    String videoId, {
    required String version,
    required String extension,
  });

  /// Deletes library thumbnails other than [keepPaths]
  Future<void> deleteThumbnailsExcept(Set<String> keepPaths);
}

final class LocalVideoLibraryDataSourceImpl
    implements LocalVideoLibraryDataSource {
  final FileSystemService _fileSystemService;

  const LocalVideoLibraryDataSourceImpl({required this._fileSystemService});

  static bool isVideoPath(String path) =>
      PlayerConstants.videoExtensions.contains(p.extension(path).toLowerCase());

  @override
  Future<bool> folderExists(String folder) => Directory(folder).exists();

  @override
  Future<List<LocalVideoFileModel>> getVideoFiles(String folder) async {
    final files = <LocalVideoFileModel>[];

    await for (final entity in Directory(folder).list(followLinks: false)) {
      if (entity is! File || !isVideoPath(entity.path)) continue;

      try {
        final stat = await entity.stat();

        files.add(
          LocalVideoFileModel(
            path: entity.path,
            sizeBytes: stat.size,
            modifiedAt: stat.modified,
          ),
        );
      } on FileSystemException {
        /// The file disappeared while the folder was read
      }
    }

    return files;
  }

  @override
  Stream<void> watchFolder(String folder) => Directory(folder)
      .watch()
      .where(
        (event) =>
            isVideoPath(event.path) ||
            (event is FileSystemMoveEvent &&
                isVideoPath(event.destination ?? '')),
      )
      .map((_) {});

  @override
  Future<bool> fileExists(String path) => File(path).exists();

  @override
  Future<void> copyFile(String from, String to) =>
      _fileSystemService.copyFile(from, to);

  Future<Directory> _thumbnailsRoot() async => Directory(
    await _fileSystemService.localAppFolder(
      StorageConstants.libraryThumbnailsFolder,
    ),
  );

  @override
  Future<String> thumbnailPath(
    String videoId, {
    required String version,
    required String extension,
  }) async =>
      p.join((await _thumbnailsRoot()).path, '$videoId-$version.$extension');

  @override
  Future<void> deleteThumbnailsExcept(Set<String> keepPaths) async {
    final root = await _thumbnailsRoot();

    if (!await root.exists()) return;

    final kept = {
      for (final path in keepPaths) p.normalize(path).toLowerCase(),
    };

    await for (final entity in root.list()) {
      if (kept.contains(p.normalize(entity.path).toLowerCase())) continue;

      try {
        await entity.delete(recursive: true);
      } on FileSystemException {
        /// The thumbnail is still shown: it goes on the next reading
      }
    }
  }
}
