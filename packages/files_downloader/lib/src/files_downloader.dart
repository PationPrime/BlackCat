import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import 'models/download_error.dart';
import 'models/download_progress.dart';
import 'models/download_request.dart';
import 'models/download_result.dart';
import 'state/download_state_file.dart';
import 'state/download_state_snapshot.dart';
import 'worker/download_worker.dart';

/// Runs downloads, each in its own isolate, so the UI isolate never waits
/// for the network or the disk.
///
/// ```dart
/// final downloader = FilesDownloader();
/// final download = await downloader.start(
///   FilesDownloadRequest(
///     id: 'movie',
///     stateDirectory: stateFolder,
///     files: [DownloadFileRequest(url: url, savePath: moviePath)],
///   ),
/// );
///
/// download.progress.listen(print);
/// final result = await download.result;
/// ```
final class FilesDownloader {
  final _downloads = <String, FilesDownload>{};

  /// Downloads that are running now
  Iterable<FilesDownload> get downloads => _downloads.values;

  FilesDownload? operator [](String id) => _downloads[id];

  /// Starts [request] in its own isolate: a paused download continues
  /// from its state. Throws [StateError] if a download with the same id
  /// is running
  Future<FilesDownload> start(FilesDownloadRequest request) async {
    if (_downloads.containsKey(request.id)) {
      throw StateError('Download ${request.id} is already running');
    }

    final download = FilesDownload._(request.id);

    _downloads[request.id] = download;
    unawaited(
      download.result.whenComplete(() => _downloads.remove(request.id)),
    );

    try {
      await download._spawn(request);
    } catch (error) {
      download._complete(
        FilesDownloadFailed(
          request.id,
          error: FilesDownloadError(
            FilesDownloadErrorType.unknown,
            'The download isolate did not start: $error',
          ),
          downloadedBytes: 0,
        ),
      );
    }

    return download;
  }

  /// Pauses every running download and waits for them
  Future<void> pauseAll() async {
    await Future.wait([
      for (final download in [...downloads]) download.pause(),
    ]);
  }

  /// `state_<id>.fds`
  static String stateFileName(String id) => DownloadStateFile.fileName(id);

  static String statePath(String stateDirectory, String id) =>
      p.join(stateDirectory, stateFileName(id));

  /// Progress a download saved. `null` when it has no state: it has not
  /// started, it finished, or its state is damaged
  static Future<DownloadStateSnapshot?> readState(
    String stateDirectory,
    String id,
  ) async =>
      (await DownloadStateFile.read(statePath(stateDirectory, id)))?.snapshot();

  /// Forgets the saved progress; the files stay
  static Future<void> deleteState(String stateDirectory, String id) async {
    final file = File(statePath(stateDirectory, id));

    if (await file.exists()) await file.delete();
  }
}

/// A running download
final class FilesDownload {
  final String id;

  final _progress = StreamController<FilesDownloadProgress>.broadcast();
  final _result = Completer<FilesDownloadResult>();
  final _pendingCommands = <Object>[];

  FilesDownloadProgress? _lastProgress;
  SendPort? _commands;
  ReceivePort? _events;
  ReceivePort? _exits;
  ReceivePort? _errors;
  Object? _crash;

  FilesDownload._(this.id);

  /// Progress, no more often than the download options say
  Stream<FilesDownloadProgress> get progress => _progress.stream;

  FilesDownloadProgress? get lastProgress => _lastProgress;

  Future<FilesDownloadResult> get result => _result.future;

  bool get isFinished => _result.isCompleted;

  /// Stops the download and keeps its files and state for resuming
  Future<FilesDownloadResult> pause() {
    _send(const WorkerStopCommand(discard: false));

    return result;
  }

  /// Stops the download and deletes its files and state
  Future<FilesDownloadResult> cancel() {
    _send(const WorkerStopCommand(discard: true));

    return result;
  }

  /// Bytes per second across all connections; `null` removes the limit
  void setSpeedLimit(int? bytesPerSecond) =>
      _send(WorkerSpeedLimitCommand(bytesPerSecond));

  void _send(Object command) {
    if (isFinished) return;

    final commands = _commands;

    if (commands == null) {
      _pendingCommands.add(command);
    } else {
      commands.send(command);
    }
  }

  Future<void> _spawn(FilesDownloadRequest request) async {
    final events = _events = ReceivePort('files_downloader:$id');
    final exits = _exits = ReceivePort();
    final errors = _errors = ReceivePort();

    events.listen(_onEvent);
    errors.listen((error) => _crash ??= error is List ? error.first : error);
    exits.listen((_) => _onExit());

    await Isolate.spawn(
      runDownloadWorker,
      WorkerBoot(host: events.sendPort, request: request),
      onExit: exits.sendPort,
      onError: errors.sendPort,
      debugName: 'files_downloader:$id',
    );
  }

  void _onEvent(Object? event) {
    switch (event) {
      case SendPort commands:
        _commands = commands;

        for (final command in _pendingCommands) {
          commands.send(command);
        }

        _pendingCommands.clear();
      case FilesDownloadProgress progress:
        _lastProgress = progress;

        if (!_progress.isClosed) _progress.add(progress);
      case FilesDownloadResult result:
        _complete(result);
    }
  }

  /// The result comes right before the exit; a worker that exits without it
  /// has crashed
  Future<void> _onExit() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));

    _complete(
      FilesDownloadFailed(
        id,
        error: FilesDownloadError(
          FilesDownloadErrorType.unknown,
          'The download isolate stopped: ${_crash ?? 'no result'}',
        ),
        downloadedBytes: _lastProgress?.downloadedBytes ?? 0,
      ),
    );
  }

  void _complete(FilesDownloadResult result) {
    if (_result.isCompleted) return;

    _result.complete(result);
    _pendingCommands.clear();
    _commands = null;
    unawaited(_progress.close());

    /// The ports close once the isolate is gone
    Future<void>.delayed(const Duration(milliseconds: 100), () {
      _events?.close();
      _exits?.close();
      _errors?.close();
    });
  }
}
