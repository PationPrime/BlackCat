import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../models/download_error.dart';
import '../models/download_options.dart';
import '../models/download_progress.dart';
import '../models/download_result.dart';
import '../models/segments_request.dart';
import '../storage/disk_space.dart';
import 'download_api_client.dart';
import 'file_errors.dart';
import 'http_errors.dart';
import 'remote_file_prober.dart';
import 'speed_control.dart';
import 'worker_engine.dart';

/// A segment being downloaded right now
final class _SegmentJob {
  final CancelToken cancelToken;
  var received = 0;

  _SegmentJob(this.cancelToken);
}

/// Runs a [SegmentsDownloadRequest] in the current isolate: several segments
/// at a time, each whole in one request.
///
/// A segment goes to `<savePath>.part` and is renamed once all of its bytes
/// are there. A resumed download counts the renamed segments as finished
/// and starts the rest over: a segment is only a few megabytes
final class SegmentsDownloadEngine implements WorkerEngine {
  static const partExtension = '.part';

  /// Less free space than this makes any file error a full disk
  static const _minimumFreeBytes = 1 << 20;

  /// Finished segments that make the average size a better estimate
  /// than the expected size
  static const _estimateSample = 8;

  final SegmentsDownloadRequest request;
  final DownloadApiClient _client;
  final void Function(FilesDownloadProgress progress) _onProgress;
  final DiskSpace _diskSpace;
  final SpeedLimiter _limiter;
  final _meter = SpeedMeter();
  final _stopSignal = Completer<void>();

  /// Segments being downloaded, by index
  final _active = <int, _SegmentJob>{};

  /// Sizes of finished segments, by index
  final _finished = <int, int>{};

  var _stage = FilesDownloadStage.preparing;
  var _stopped = false;
  var _discard = false;
  FilesDownloadError? _failure;

  SegmentsDownloadEngine({
    required this.request,
    required this._client,
    required this._onProgress,
    this._diskSpace = const SystemDiskSpace(),
  }) : _limiter = SpeedLimiter(bytesPerSecond: request.options.speedLimit);

  FilesDownloadOptions get _options => request.options;

  List<DownloadSegmentRequest> get _segments => request.segments;

  bool get _halted => _stopped || _failure != null;

  static File _partOf(DownloadSegmentRequest segment) =>
      File('${segment.savePath}$partExtension');

  @override
  void stop({bool discard = false}) {
    _discard = _discard || discard;

    if (_stopped) return;

    _stopped = true;
    _halt();
  }

  @override
  void setSpeedLimit(int? bytesPerSecond) =>
      _limiter.bytesPerSecond = bytesPerSecond;

  void _halt() {
    for (final job in _active.values) {
      job.cancelToken.cancel();
    }

    if (!_stopSignal.isCompleted) _stopSignal.complete();
  }

  void _fail(FilesDownloadError error) {
    if (_failure != null || _stopped) return;

    _failure = error;
    _halt();
  }

  void _throwIfHalted() {
    if (_halted) throw const DownloadStoppedSignal();
  }

  /// Waits, but wakes up when the download stops
  Future<void> _delay(Duration duration) async {
    if (duration <= Duration.zero) return;

    await Future.any([Future<void>.delayed(duration), _stopSignal.future]);
    _throwIfHalted();
  }

  Duration _backoff(int failures) =>
      _options.retryBaseDelay * math.pow(2, math.max(0, failures - 1)).toInt();

  @override
  Future<FilesDownloadResult> run() async {
    Timer? progressTimer;

    try {
      /// Finished segments count from the first progress on
      _prepare();
      _emitProgress();
      _throwIfHalted();

      _stage = FilesDownloadStage.downloading;
      _emitProgress();

      progressTimer = Timer.periodic(
        _options.progressInterval,
        (_) => _guarded(_emitProgress),
      );

      await _runSegments();
    } on DownloadStoppedSignal {
      /// Stopped or failed: the result tells which
    } on FilesDownloadError catch (error) {
      _fail(error);
    } on FileSystemException catch (error) {
      _fail(_diskError(error));
    } catch (error) {
      _fail(_unexpected(error));
    } finally {
      progressTimer?.cancel();
    }

    return _finish();
  }

  static FilesDownloadError _unexpected(Object error) =>
      FilesDownloadError(FilesDownloadErrorType.unknown, '$error');

  /// Timer work never ends the isolate: an error fails the download
  void _guarded(void Function() action) {
    try {
      action();
    } catch (error) {
      _fail(_unexpected(error));
    }
  }

  /// Counts the finished segments, drops unfinished parts of the last run
  /// and checks that the rest fits on the disk
  void _prepare() {
    final folders = <String>{};

    for (final (index, segment) in _segments.indexed) {
      final file = File(segment.savePath);

      folders.add(file.parent.path);

      if (file.existsSync()) {
        final length = file.lengthSync();

        if (length > 0) {
          _finished[index] = length;
        } else {
          file.deleteSync();
        }
      }

      final part = _partOf(segment);

      if (part.existsSync()) part.deleteSync();
    }

    for (final folder in folders) {
      Directory(folder).createSync(recursive: true);
    }

    final needed = math.max(0, (request.expectedBytes ?? 0) - _finishedBytes);
    final path = _segments.firstOrNull?.savePath;

    if (needed == 0 || path == null) return;

    final available = _availableBytes(path);

    if (available != null && needed + _minimumFreeBytes > available) {
      throw diskFullError(
        path: path,
        neededBytes: needed,
        availableBytes: available,
      );
    }
  }

  Future<void> _runSegments() async {
    final queue = Queue.of([
      for (var index = 0; index < _segments.length; index++)
        if (!_finished.containsKey(index)) index,
    ]);

    Future<void> worker() async {
      while (!_halted && queue.isNotEmpty) {
        await _runSegment(queue.removeFirst());
      }
    }

    await Future.wait([
      for (var i = 0; i < math.min(_options.maxConnections, queue.length); i++)
        worker(),
    ]);

    _throwIfHalted();
  }

  /// Downloads one segment, retrying what another attempt may get past
  Future<void> _runSegment(int index) async {
    final segment = _segments[index];
    var failures = 0;

    while (true) {
      try {
        _throwIfHalted();
        await _fetch(index);

        return;
      } on DownloadStoppedSignal {
        return;
      } on FilesDownloadError catch (error) {
        if (!error.isRetryable || ++failures > _options.maxRetries) {
          _fail(error);

          return;
        }

        try {
          await _delay(_backoff(failures));
        } on DownloadStoppedSignal {
          return;
        }
      } on FileSystemException catch (error) {
        _fail(_diskError(error, path: segment.savePath));

        return;
      } catch (error) {
        _fail(
          FilesDownloadError(
            FilesDownloadErrorType.unknown,
            '$error',
            url: segment.url,
          ),
        );

        return;
      }
    }
  }

  /// One request of a segment: the whole body goes to its part file,
  /// which becomes the segment once complete
  Future<void> _fetch(int index) async {
    final segment = _segments[index];
    final part = _partOf(segment);
    final cancelToken = CancelToken();
    final job = _active[index] = _SegmentJob(cancelToken);
    RandomAccessFile? output;

    if (_halted) cancelToken.cancel();

    try {
      final Response<ResponseBody> response;

      try {
        response = await _client.dio.get<ResponseBody>(
          segment.url,
          cancelToken: cancelToken,
        );
      } on DioException catch (error) {
        throw dioError(error, segment.url);
      }

      final status = response.statusCode ?? 0;
      final body = response.data!.stream;

      if (status != 200) {
        unawaited(body.listen(null, onError: (_) {}).cancel());

        throw statusError(status, segment.url);
      }

      final expected = RemoteFileProber.contentLengthOf(response.headers);

      output = part.openSync(mode: FileMode.write);

      try {
        await for (final chunk in body.timeout(_options.idleTimeout)) {
          _throwIfHalted();
          await _delay(_limiter.reserve(chunk.length));

          output.writeFromSync(chunk);
          job.received += chunk.length;
          _meter.add(chunk.length);
        }
      } catch (error) {
        if (error is DownloadStoppedSignal ||
            _halted ||
            (error is DioException && CancelToken.isCancel(error))) {
          throw const DownloadStoppedSignal();
        }

        throw streamError(error, segment.url) ?? error;
      }

      if (job.received == 0 || (expected != null && job.received != expected)) {
        throw FilesDownloadError(
          FilesDownloadErrorType.network,
          'The connection closed after ${job.received} of '
          '${expected ?? 'unknown'} bytes',
          url: segment.url,
        );
      }

      output.closeSync();
      output = null;
      part.renameSync(segment.savePath);
      _finished[index] = job.received;
    } finally {
      _active.remove(index);

      try {
        output?.closeSync();
      } on FileSystemException {
        /// The part is thrown away below anyway
      }

      /// An unfinished segment starts over next time
      if (!_finished.containsKey(index)) {
        try {
          if (part.existsSync()) part.deleteSync();
        } on FileSystemException {
          /// The next run drops it before starting
        }
      }
    }
  }

  int? _availableBytes(String path) {
    try {
      return _diskSpace.availableBytes(path);
    } catch (_) {
      return null;
    }
  }

  /// A file error, told apart from a full disk as in the sliced downloads
  FilesDownloadError _diskError(FileSystemException error, {String? path}) {
    final target =
        path ?? error.path ?? _segments.firstOrNull?.savePath ?? request.id;

    return fileError(
      error,
      path: target,
      neededBytes: math.max(0, (_totalBytes ?? 0) - _downloadedBytes),
      availableBytes: () => _availableBytes(target),
      minimumFreeBytes: _minimumFreeBytes,
    );
  }

  int get _finishedBytes => _finished.values.fold(0, (a, b) => a + b);

  int get _downloadedBytes =>
      _finishedBytes +
      _active.values.fold<int>(0, (sum, job) => sum + job.received);

  /// Exact once every segment is finished. Before that the expected size,
  /// then the average of the finished segments for all of them
  int? get _totalBytes {
    final count = _segments.length;

    if (_finished.length == count) return _finishedBytes;

    final average = _finished.isEmpty
        ? null
        : (_finishedBytes / _finished.length * count).round();
    final estimate =
        _finished.length >= math.min(_estimateSample, count) ||
            request.expectedBytes == null
        ? average ?? request.expectedBytes
        : request.expectedBytes;

    return estimate == null ? null : math.max(estimate, _downloadedBytes);
  }

  void _emitProgress() => _onProgress(
    FilesDownloadProgress(
      id: request.id,
      stage: _stage,
      downloadedBytes: _downloadedBytes,
      totalBytes: _totalBytes,
      bytesPerSecond: _stage == FilesDownloadStage.downloading
          ? _meter.bytesPerSecond
          : null,
      activeConnections: _active.length,
    ),
  );

  FilesDownloadResult _finish() {
    try {
      final failure = _failure;

      if (failure != null) {
        _emitProgress();

        return FilesDownloadFailed(
          request.id,
          error: failure,
          downloadedBytes: _finishedBytes,
        );
      }

      if (_stopped) {
        if (_discard) {
          for (final segment in _segments) {
            for (final file in [File(segment.savePath), _partOf(segment)]) {
              if (file.existsSync()) file.deleteSync();
            }
          }

          return FilesDownloadStopped(
            request.id,
            downloadedBytes: 0,
            totalBytes: null,
            discarded: true,
          );
        }

        _emitProgress();

        return FilesDownloadStopped(
          request.id,
          downloadedBytes: _finishedBytes,
          totalBytes: _totalBytes,
        );
      }

      _stage = FilesDownloadStage.finishing;
      _emitProgress();

      return FilesDownloadCompleted(
        request.id,
        files: [
          for (final (index, segment) in _segments.indexed)
            DownloadedFile(path: segment.savePath, length: _finished[index]!),
        ],
      );
    } on FileSystemException catch (error) {
      return FilesDownloadFailed(
        request.id,
        error: _diskError(error),
        downloadedBytes: _finishedBytes,
      );
    } catch (error) {
      /// The result always comes: the isolate never ends with a raw error
      return FilesDownloadFailed(
        request.id,
        error: _failure ?? _unexpected(error),
        downloadedBytes: 0,
      );
    }
  }
}
