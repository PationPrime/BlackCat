import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';
import 'package:files_downloader/files_downloader.dart';
import 'package:path/path.dart' as p;
import 'package:peeky_cat/src/app/constants/constants.dart';
import 'package:peeky_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:peeky_cat/src/app/logger/app_logger.dart';
import 'package:peeky_cat/src/app/services/services.dart';

part 'direct_download_state.dart';

/// Downloads a file by its link with [FilesDownloader] alone: the section
/// of the home page that tells a slow downloader apart from a slow source.
/// The settings are the ones the YouTube streams are downloaded with, so
/// the only difference from a video download is where the bytes come from.
///
/// One download at a time and nothing in the database: a restart of the app
/// forgets the link. The file and its state file stay in the app folder,
/// so a download stopped by the restart can be started again by hand
class DirectDownloadController extends Cubit<DirectDownloadState> {
  static const _appLogger = AppLogger(where: 'DirectDownloadController');

  /// Progress is reported this often; the progress bar animates over
  /// the same time, so it moves smoothly
  static const progressInterval = Duration(milliseconds: 250);

  /// The only download of the section. Its state file is `state_direct.fds`:
  /// a paused link continues from it
  static const _downloadId = 'direct';

  /// Files and their state next to the other app data
  static const _folder = 'Direct downloads';

  /// Names that are not a file name of their own
  static const _reservedNames = {'', '.', '..'};

  static const _maxFileNameLength = 120;

  static final _unsafeCharacters = RegExp(r'[^A-Za-z0-9._-]');

  /// What a YouTube stream is downloaded with: the section compares sources,
  /// not settings
  static const _options = FilesDownloadOptions(
    sliceSize: YouTubeConstants.streamChunkSize,
    maxConnections: YouTubeConstants.streamConnections,
    progressInterval: progressInterval,

    /// Servers that answer a plain `dart:io` client with an error status
    /// answer a browser
    headers: {'User-Agent': YouTubeConstants.browserUserAgent},
  );

  final FileSystemService _fileSystemService;
  final FilesDownloader _filesDownloader;

  FilesDownload? _download;
  StreamSubscription<FilesDownloadProgress>? _progressSubscription;

  DirectDownloadController({
    required this._fileSystemService,
    FilesDownloader? filesDownloader,
  }) : _filesDownloader = filesDownloader ?? FilesDownloader(),
       super(const DirectDownloadState());

  void _safeEmit(DirectDownloadState state) {
    if (isClosed) return;

    emit(state);
  }

  @override
  Future<void> close() async {
    /// Not awaited: the download isolate outlives the page otherwise, and
    /// the futures here belong to the root zone
    unawaited(_download?.pause());
    unawaited(_progressSubscription?.cancel());

    await super.close();
  }

  /// Starts [url]; a link that is already downloading is ignored
  Future<void> start(String url) async {
    if (state.isBusy) return;

    final link = _parseLink(url);

    if (link == null) {
      _safeEmit(
        DirectDownloadState(
          status: DirectDownloadStatus.failed,
          url: url.trim(),
          errorMessage: LocaleKeys.app_home_direct_invalid_url.tr(),
        ),
      );

      return;
    }

    final address = link.toString();

    _safeEmit(
      DirectDownloadState(
        status: DirectDownloadStatus.starting,
        url: address,
        fileName: _fileNameOf(link),
      ),
    );

    await _run();
  }

  /// Stops the download and keeps what is on disk
  Future<void> pause() async {
    await _download?.pause();
  }

  /// Continues a stopped link from the bytes already on disk
  Future<void> resume() async {
    if (!state.canResume) return;

    _safeEmit(
      state.copyWith(
        status: DirectDownloadStatus.starting,
        stage: FilesDownloadStage.probing,
        clearErrorMessage: true,
      ),
    );

    await _run();
  }

  /// Forgets the link and deletes what it left on disk
  Future<void> cancel() async {
    final download = _download;

    if (download != null) {
      /// The result clears the state once the isolate is gone
      await download.cancel();

      return;
    }

    await _deleteLeftovers();

    _safeEmit(const DirectDownloadState());
  }

  /// One run of the download isolate: it ends with a result, and the result
  /// tells whether the file is complete, paused or failed
  Future<void> _run() async {
    try {
      final folder = await _fileSystemService.localAppFolder(_folder);

      await Directory(folder).create(recursive: true);

      final savePath = p.join(folder, state.fileName);
      final download = _download = await _filesDownloader.start(
        FilesDownloadRequest(
          id: _downloadId,
          stateDirectory: folder,
          options: _options,
          files: [DownloadFileRequest(url: state.url, savePath: savePath)],
        ),
      );

      _safeEmit(state.copyWith(savePath: savePath));

      _progressSubscription = download.progress.listen(_onProgress);

      _onResult(await download.result);
    } catch (error, stackTrace) {
      _appLogger.logError('$error', stackTrace: stackTrace);
      _safeEmit(
        state.copyWith(
          status: DirectDownloadStatus.failed,
          activeConnections: 0,
          errorMessage: '$error',
          clearSpeed: true,
        ),
      );
    } finally {
      unawaited(_progressSubscription?.cancel());

      _progressSubscription = null;
      _download = null;
    }
  }

  void _onProgress(FilesDownloadProgress progress) => _safeEmit(
    state.copyWith(
      status: DirectDownloadStatus.downloading,
      stage: progress.stage,
      downloadedBytes: progress.downloadedBytes,
      totalBytes: progress.totalBytes,
      bytesPerSecond: progress.bytesPerSecond,
      activeConnections: progress.activeConnections,
      clearTotalBytes: progress.totalBytes == null,
      clearSpeed: progress.bytesPerSecond == null,
    ),
  );

  void _onResult(FilesDownloadResult result) {
    switch (result) {
      case FilesDownloadCompleted(:final files):
        final file = files.first;

        _safeEmit(
          state.copyWith(
            status: DirectDownloadStatus.completed,
            savePath: file.path,
            downloadedBytes: file.length,
            totalBytes: file.length,
            activeConnections: 0,
            clearSpeed: true,
          ),
        );
      case FilesDownloadStopped(discarded: true):
        _safeEmit(const DirectDownloadState());
      case FilesDownloadStopped(:final downloadedBytes, :final totalBytes):
        _safeEmit(
          state.copyWith(
            status: DirectDownloadStatus.paused,
            downloadedBytes: downloadedBytes,
            totalBytes: totalBytes,
            activeConnections: 0,
            clearTotalBytes: totalBytes == null,
            clearSpeed: true,
          ),
        );
      case FilesDownloadFailed(:final error, :final downloadedBytes):
        _appLogger.logMessage('Direct download failed: $error');
        _safeEmit(
          state.copyWith(
            status: DirectDownloadStatus.failed,
            downloadedBytes: downloadedBytes,
            activeConnections: 0,
            errorMessage: _messageOf(error),
            clearSpeed: true,
          ),
        );
    }
  }

  /// The downloader's own words: the section is a diagnostic tool, its errors
  /// are meant to be read as they are
  static String _messageOf(FilesDownloadError error) => [
    error.message,
    if (error.statusCode case final status?) 'HTTP $status',
  ].join(' · ');

  Future<void> _deleteLeftovers() async {
    final savePath = state.savePath;

    if (savePath == null) return;

    await FilesDownloader.deleteState(p.dirname(savePath), _downloadId);
    await _fileSystemService.deleteFile(savePath);
  }

  /// Only an `http`/`https` link with a host can be downloaded
  static Uri? _parseLink(String url) {
    final link = Uri.tryParse(url.trim());

    if (link == null ||
        !link.hasAuthority ||
        (link.scheme != 'http' && link.scheme != 'https')) {
      return null;
    }

    return link;
  }

  /// The name from the link without its query, made safe for a file system.
  /// A link that names nothing becomes `download.bin`
  static String _fileNameOf(Uri link) {
    final last = link.pathSegments.isEmpty ? '' : link.pathSegments.last;
    final safe = last.replaceAll(_unsafeCharacters, '_');
    final name = safe.length <= _maxFileNameLength
        ? safe
        : safe.substring(0, _maxFileNameLength);

    return _reservedNames.contains(name) ? 'download.bin' : name;
  }
}
