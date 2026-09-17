import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../data_sources/data_sources.dart';
import '../../dto/dto.dart';
import '../../errors/errors.dart';
import '../../failure/failure.dart';
import '../../models/models.dart';
import '../../operation_result/operation_result.dart';
import '../../services/services.dart';
import '../../storage/database/providers/providers.dart';
import 'video_library_repository_interface.dart';

final class VideoLibraryRepository implements VideoLibraryRepositoryInterface {
  static const _thumbnailExtension = 'jpg';

  final LibraryVideoTableProvider _libraryVideoTableProvider;
  final DownloadTaskTableProvider _downloadTaskTableProvider;
  final LocalVideoLibraryDataSource _localVideoLibraryDataSource;
  final VideoMetadataService _videoMetadataService;

  /// Linux file systems tell apart paths that differ only in letter case
  final bool _caseSensitivePaths;

  VideoLibraryRepository({
    required this._libraryVideoTableProvider,
    required this._downloadTaskTableProvider,
    required this._localVideoLibraryDataSource,
    required this._videoMetadataService,
    bool? caseSensitivePaths,
  }) : _caseSensitivePaths = caseSensitivePaths ?? Platform.isLinux;

  @override
  ErrorHandler<PlayerErrorCodes> get errorHandler => const PlayerErrorHandler();

  Failure _storageFailure(Object error, StackTrace stackTrace) =>
      errorHandler.handleError(
        PlayerException(const PlayerErrorCodes().storage, cause: error),
        stackTrace: stackTrace,
      );

  /// Windows and macOS paths do not depend on the letter case
  String _pathKey(String path) {
    final normalized = p.normalize(path);

    return _caseSensitivePaths ? normalized : normalized.toLowerCase();
  }

  String _idOf(String path) => '${sha1.convert(utf8.encode(_pathKey(path)))}';

  /// The database keeps time to the second
  static DateTime _toSeconds(DateTime time) =>
      DateTime.fromMillisecondsSinceEpoch(
        time.millisecondsSinceEpoch - time.millisecondsSinceEpoch % 1000,
      );

  static String _versionOf(DateTime modifiedAt) =>
      '${modifiedAt.millisecondsSinceEpoch ~/ 1000}';

  @override
  Future<OperationResult<List<LibraryVideoModel>>> syncVideos(
    String folder,
  ) async {
    try {
      if (!await _localVideoLibraryDataSource.folderExists(folder)) {
        return fail(
          errorHandler.handleError(
            PlayerException(
              const PlayerErrorCodes().folderNotFound,
              path: folder,
            ),
          ),
        );
      }

      final files = await _localVideoLibraryDataSource.getVideoFiles(folder);
      final stored = {
        for (final video in await _libraryVideoTableProvider.getVideos())
          video.id: video.toModel(),
      };
      final downloads = await _downloadsByPath();
      final videos = <LibraryVideoModel>[];
      final added = <LibraryVideoModel>[];

      for (final file in files) {
        final id = _idOf(file.path);
        final modifiedAt = _toSeconds(file.modifiedAt);

        if (stored[id] case final existing?
            when existing.sizeBytes == file.sizeBytes &&
                existing.modifiedAt.isAtSameMomentAs(modifiedAt)) {
          videos.add(existing);

          continue;
        }

        final video = await _newVideo(
          id: id,
          file: file,
          modifiedAt: modifiedAt,
          download: downloads[_pathKey(file.path)],
        );

        videos.add(video);
        added.add(video);
      }

      final ids = {for (final video in videos) video.id};

      await _libraryVideoTableProvider.deleteVideos([
        for (final id in stored.keys)
          if (!ids.contains(id)) id,
      ]);
      await _libraryVideoTableProvider.saveVideos([
        for (final video in added) LibraryVideoDto.fromModel(video),
      ]);
      await _localVideoLibraryDataSource.deleteThumbnailsExcept({
        for (final video in videos) ?video.thumbnailPath,
      });

      return ok(
        videos
          ..sort((left, right) => right.modifiedAt.compareTo(left.modifiedAt)),
      );
    } catch (error, stackTrace) {
      return fail(_storageFailure(error, stackTrace));
    }
  }

  /// Finished downloads by the path of their file
  Future<Map<String, DownloadTaskDto>> _downloadsByPath() async => {
    for (final task in await _downloadTaskTableProvider.getTasks())
      if (task.status.isDone && task.filePath != null)
        _pathKey(task.filePath!): task,
  };

  /// A file the library has not seen: a download of the app keeps its title,
  /// duration and a copy of its thumbnail, the system is asked for the rest
  /// later
  Future<LibraryVideoModel> _newVideo({
    required String id,
    required LocalVideoFileModel file,
    required DateTime modifiedAt,
    required DownloadTaskDto? download,
  }) async {
    final thumbnailPath = await _copyDownloadThumbnail(
      id,
      modifiedAt,
      download?.thumbnailPath,
    );
    final duration = switch (download?.durationSeconds) {
      final seconds? when seconds > 0 => Duration(
        milliseconds: (seconds * 1000).round(),
      ),
      _ => null,
    };

    return LibraryVideoModel(
      id: id,
      path: file.path,
      title: download?.title ?? p.basenameWithoutExtension(file.path),
      sizeBytes: file.sizeBytes,
      modifiedAt: modifiedAt,
      duration: duration,
      thumbnailPath: thumbnailPath,
      isMetadataLoaded: thumbnailPath != null && duration != null,
    );
  }

  /// The download thumbnail goes away with the download: the library
  /// keeps its own copy
  Future<String?> _copyDownloadThumbnail(
    String id,
    DateTime modifiedAt,
    String? source,
  ) async {
    if (source == null ||
        !await _localVideoLibraryDataSource.fileExists(source)) {
      return null;
    }

    final extension = p.extension(source).replaceFirst('.', '');
    final target = await _localVideoLibraryDataSource.thumbnailPath(
      id,
      version: _versionOf(modifiedAt),
      extension: extension.isEmpty ? _thumbnailExtension : extension,
    );

    try {
      await _localVideoLibraryDataSource.copyFile(source, target);

      return target;
    } catch (_) {
      /// The system gives its own thumbnail then
      return null;
    }
  }

  @override
  Future<OperationResult<LibraryVideoModel>> loadMetadata(
    LibraryVideoModel video,
  ) async {
    try {
      final thumbnailPath = video.thumbnailPath == null
          ? await _localVideoLibraryDataSource.thumbnailPath(
              video.id,
              version: _versionOf(video.modifiedAt),
              extension: _thumbnailExtension,
            )
          : null;
      final metadata = await _videoMetadataService.read(
        video.path,
        thumbnailPath: thumbnailPath,
      );
      final loaded = LibraryVideoModel(
        id: video.id,
        path: video.path,
        title: video.title,
        sizeBytes: video.sizeBytes,
        modifiedAt: video.modifiedAt,
        duration: video.duration ?? metadata.duration,
        position: video.position,
        thumbnailPath:
            video.thumbnailPath ??
            (metadata.hasThumbnail ? thumbnailPath : null),
        isMetadataLoaded: true,
        watchedAt: video.watchedAt,
      );

      await _libraryVideoTableProvider.updateMetadata(
        videoId: loaded.id,
        durationMs: loaded.duration?.inMilliseconds,
        thumbnailPath: loaded.thumbnailPath,
      );

      return ok(loaded);
    } catch (error, stackTrace) {
      return fail(_storageFailure(error, stackTrace));
    }
  }

  @override
  Future<OperationResult<void>> savePosition(LibraryVideoModel video) async {
    try {
      await _libraryVideoTableProvider.updatePosition(
        videoId: video.id,
        positionMs: video.position.inMilliseconds,
        durationMs: video.duration?.inMilliseconds,
        watchedAt: video.watchedAt ?? DateTime.now(),
      );

      return ok(null);
    } catch (error, stackTrace) {
      return fail(_storageFailure(error, stackTrace));
    }
  }

  @override
  Stream<void> watchFolder(String folder) =>
      _localVideoLibraryDataSource.watchFolder(folder);
}
