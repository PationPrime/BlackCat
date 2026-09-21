import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../models/byte_ranges.dart';
import '../models/download_error.dart';
import '../models/download_options.dart';
import '../models/download_progress.dart';
import '../models/download_request.dart';
import '../models/download_result.dart';
import '../models/remote_file_info.dart';
import '../state/download_state_file.dart';
import '../storage/disk_space.dart';
import 'download_api_client.dart';
import 'file_errors.dart';
import 'http_errors.dart';
import 'remote_file_prober.dart';
import 'slice_job.dart';
import 'speed_control.dart';
import 'worker_engine.dart';

/// Runs one download in the current isolate: asks the servers about
/// the files, reserves them on disk, downloads the missing slices over
/// several connections and saves slice progress in the state file.
///
/// File writes are synchronous: the engine runs in its own isolate,
/// and no two writes to a file can overlap
final class DownloadEngine implements WorkerEngine {
  /// NTFS gives an extended file its space right away; APFS and ext4 make
  /// it sparse and take the space as the bytes are written
  static final _reservesSpace = Platform.isWindows;

  /// Less free space than this makes any file error a full disk: nothing
  /// can be written anymore
  static const _minimumFreeBytes = 1 << 20;

  final FilesDownloadRequest request;
  final DownloadApiClient _client;
  final void Function(FilesDownloadProgress progress) _onProgress;
  final DiskSpace _diskSpace;
  final SpeedLimiter _limiter;
  final _meter = SpeedMeter();

  final _probeToken = CancelToken();
  final _stopSignal = Completer<void>();
  final _activeJobs = <SliceJob>{};

  var _stage = FilesDownloadStage.probing;
  var _stopped = false;
  var _discard = false;
  FilesDownloadError? _failure;

  /// Written bytes could not be flushed or saved. After a pause this is
  /// still a failure: the next start downloads the unsaved bytes again
  FilesDownloadError? _saveFailure;

  List<RemoteFileInfo> _infos = const [];
  DownloadStateFile? _state;

  /// Bytes on disk of each slice of each file, including unsaved ones
  List<List<int>> _live = const [];

  /// State of a previous run: progress while the servers are asked
  DownloadStateFile? _previousState;

  /// Bytes of each file the previous run left on disk
  List<int> _previousBytes = const [];

  DownloadEngine({
    required this.request,
    required this._client,
    required this._onProgress,
    this._diskSpace = const SystemDiskSpace(),
  }) : _limiter = SpeedLimiter(bytesPerSecond: request.options.speedLimit);

  FilesDownloadOptions get _options => request.options;

  List<DownloadFileRequest> get _files => request.files;

  String get statePath =>
      p.join(request.stateDirectory, DownloadStateFile.fileName(request.id));

  bool get _halted => _stopped || _failure != null;

  /// Pauses the download; [discard] deletes the files and the state
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
    _probeToken.cancel();

    for (final job in _activeJobs) {
      job.cancelToken?.cancel();
    }

    if (!_stopSignal.isCompleted) _stopSignal.complete();
  }

  void _fail(FilesDownloadError error) {
    if (_failure != null || _stopped) return;

    _failure = error;
    _halt();
  }

  void _failSaving(FileSystemException error, {required String path}) {
    final failure = _diskError(error, path: path);

    _saveFailure ??= failure;
    _fail(failure);
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

  @override
  Future<FilesDownloadResult> run() async {
    Timer? progressTimer;
    Timer? checkpointTimer;

    try {
      _previousState = DownloadStateFile.readSync(statePath);
      _previousBytes = _bytesOnDisk(_previousState);
      _emitProgress();

      _infos = await _probeAll();
      _throwIfHalted();

      _stage = FilesDownloadStage.preparing;
      _emitProgress();

      final jobs = _prepare();

      _throwIfHalted();
      _stage = FilesDownloadStage.downloading;
      _emitProgress();

      progressTimer = Timer.periodic(
        _options.progressInterval,
        (_) => _guarded(_emitProgress),
      );
      checkpointTimer = Timer.periodic(
        _options.checkpointInterval,
        (_) => _guarded(_checkpoint),
      );

      await _runJobs(jobs);
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
      checkpointTimer?.cancel();
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

  /// A file error, told apart from a full disk: the system may say so
  /// outright, or the free space shows that the download cannot fit.
  /// The space is checked only for errors that may come from its lack
  FilesDownloadError _diskError(
    FileSystemException error, {
    String? path,
    int? neededBytes,
  }) {
    final target =
        path ?? error.path ?? _files.firstOrNull?.savePath ?? statePath;

    return fileError(
      error,
      path: target,
      neededBytes: neededBytes ?? _stillNeededBytes(),
      availableBytes: () => _availableBytes(target),
      minimumFreeBytes: _minimumFreeBytes,
    );
  }

  int? _availableBytes(String path) {
    try {
      return _diskSpace.availableBytes(path);
    } catch (_) {
      return null;
    }
  }

  /// Length of the file on disk, `-1` if there is none or it cannot be read
  static int _lengthOn(String path) {
    try {
      final file = File(path);

      return file.existsSync() ? file.lengthSync() : -1;
    } on FileSystemException {
      return -1;
    }
  }

  /// Bytes the disk still has to give the download: the unwritten rest
  /// of each file of a known size, unless the file already holds its space
  int _stillNeededBytes() {
    var needed = 0;

    for (var file = 0; file < _files.length; file++) {
      final info = _infos.elementAtOrNull(file);
      final length = info?.length;

      if (length == null) continue;

      final reserved =
          _reservesSpace &&
          info!.isSliceable &&
          _lengthOn(_files[file].savePath) == length;

      if (!reserved) needed += math.max(0, length - _fileBytes(file));
    }

    return needed;
  }

  /// Before anything is reserved, the disk must hold what the download
  /// still needs. Files on one volume share its free space
  void _checkFreeSpace(DownloadStateFile state) {
    final neededByVolume = <String, int>{};
    final pathsByVolume = <String, List<String>>{};

    for (var file = 0; file < _files.length; file++) {
      final info = _infos[file];
      final length = info.length;

      if (length == null) continue;

      final path = _files[file].savePath;
      final onDisk = math.max(0, _lengthOn(path));

      /// A reserved file needs only its growth; a sparse one needs every
      /// byte not downloaded yet. A file without parts is written anew
      final needed = _reservesSpace || !info.isSliceable
          ? length - onDisk
          : length - state.downloadedBytes(file);
      final volume = _volumeOf(path);

      neededByVolume[volume] =
          (neededByVolume[volume] ?? 0) + math.max(0, needed);
      (pathsByVolume[volume] ??= []).add(path);
    }

    for (final MapEntry(key: volume, value: needed) in neededByVolume.entries) {
      if (needed <= 0) continue;

      final paths = pathsByVolume[volume]!;
      final available = paths
          .map(_availableBytes)
          .nonNulls
          .fold<int?>(
            null,
            (least, bytes) => least == null ? bytes : math.min(least, bytes),
          );

      if (available != null && needed + _minimumFreeBytes > available) {
        throw diskFullError(
          path: paths.first,
          neededBytes: needed,
          availableBytes: available,
        );
      }
    }
  }

  /// Drive letters tell volumes apart on Windows; elsewhere the files
  /// of one download are taken as one volume
  static String _volumeOf(String path) =>
      Platform.isWindows ? p.rootPrefix(p.absolute(path)).toLowerCase() : '';

  Duration _backoff(int failures) =>
      _options.retryBaseDelay * math.pow(2, math.max(0, failures - 1)).toInt();

  /// Retries what may pass on another attempt
  Future<T> _retrying<T>(Future<T> Function() action) async {
    var failures = 0;

    while (true) {
      _throwIfHalted();

      try {
        return await action();
      } on FilesDownloadError catch (error) {
        if (!error.isRetryable || ++failures > _options.maxRetries) rethrow;

        await _delay(_backoff(failures));
      }
    }
  }

  Future<List<RemoteFileInfo>> _probeAll() async {
    final prober = RemoteFileProber(_client);
    final infos = List<RemoteFileInfo?>.filled(_files.length, null);
    var next = 0;

    Future<void> worker() async {
      while (next < _files.length) {
        final index = next++;

        infos[index] = await _retrying(
          () => prober.probe(_files[index], cancelToken: _probeToken),
        );
      }
    }

    await Future.wait([
      for (var i = 0; i < math.min(_options.maxConnections, _files.length); i++)
        worker(),
    ]);

    return [for (final info in infos) info!];
  }

  StateFileEntry _entryOf(int file) => StateFileEntry(
    identity: _files[file].identity,
    length: _infos[file].length,
    acceptsRanges: _infos[file].isSliceable,
    validator: _infos[file].validator,
  );

  /// Opens or creates the state and reserves the files. Returns the slices
  /// still to download
  List<SliceJob> _prepare() {
    final entries = [for (var i = 0; i < _files.length; i++) _entryOf(i)];
    final previous = _previousState;
    final reusable =
        previous != null &&
        previous.sliceSize == _options.sliceSize &&
        previous.entries.length == entries.length &&
        [
          for (var i = 0; i < entries.length; i++)
            previous.entries[i].matches(
              entries[i],
              checkValidator: _files[i].checkValidator,
            ),
        ].every((matches) => matches);

    final DownloadStateFile state;

    if (reusable) {
      state = previous;
    } else {
      previous?.deleteSync();
      state = DownloadStateFile.createSync(
        statePath,
        sliceSize: _options.sliceSize,
        entries: entries,
        counters: [
          for (var i = 0; i < entries.length; i++) _adoptedCounters(i),
        ],
      );
    }

    _state = state;
    _previousState = null;

    for (var file = 0; file < _files.length; file++) {
      _fitToDisk(state, file, stateReused: reusable);
    }

    _live = [
      for (var file = 0; file < _files.length; file++) state.counters(file),
    ];

    _checkFreeSpace(state);

    for (var file = 0; file < _files.length; file++) {
      _reserve(file);
    }

    state.flushSync();

    return [
      for (var file = 0; file < _files.length; file++)
        if (_infos[file].isSliceable)
          for (var slice = 0; slice < state.sliceCount(file); slice++)
            if (!state.isSliceComplete(file, slice))
              SliceJob(
                file: file,
                slice: slice,
                request: _files[file],
                info: _infos[file],
                range: state.sliceRange(file, slice),
                downloaded: state.counter(file, slice),
              )
            else
              null
        else
          SliceJob(
            file: file,
            slice: 0,
            request: _files[file],
            info: _infos[file],
            range: null,
          ),
    ].nonNulls.toList();
  }

  /// Counters of a new state: a file already on disk is kept as downloaded
  /// in order when the options say so
  List<int> _adoptedCounters(int file) {
    final info = _infos[file];
    final length = info.length;

    if (_options.existingFilePolicy != ExistingFilePolicy.continuePrefix ||
        length == null ||
        !info.isSliceable) {
      return const [];
    }

    final existing = File(_files[file].savePath);
    final existingLength = existing.existsSync() ? existing.lengthSync() : 0;

    if (existingLength > length) return const [];

    return SliceLayout(
      fileLength: length,
      sliceSize: _options.sliceSize,
    ).prefixCounters(existingLength);
  }

  /// Counters never claim bytes past the end of what is on disk
  void _fitToDisk(
    DownloadStateFile state,
    int file, {
    required bool stateReused,
  }) {
    final info = _infos[file];
    final length = info.length;

    /// Files without parts are downloaded from the start: their counters
    /// only show progress
    if (length == null || !info.isSliceable) {
      state.resetFile(file);

      return;
    }

    final existingLength = _lengthOn(_files[file].savePath);

    if (existingLength == length ||
        !(stateReused ||
            _options.existingFilePolicy == ExistingFilePolicy.replace)) {
      return;
    }

    for (var slice = 0; slice < state.sliceCount(file); slice++) {
      final range = state.sliceRange(file, slice)!;
      final onDisk = math.max(0, existingLength - range.start);

      if (state.counter(file, slice) > onDisk) {
        state.setCounter(file, slice, onDisk);
      }
    }
  }

  /// Gives a sliced file its full size on disk
  void _reserve(int file) {
    final info = _infos[file];
    final length = info.length;
    final target = File(_files[file].savePath);

    try {
      target.parent.createSync(recursive: true);

      if (length == null || !info.isSliceable) return;

      final existingLength = _lengthOn(target.path);

      if (existingLength == length) return;

      final output = target.openSync(mode: FileMode.append);

      try {
        output.truncateSync(length);
      } finally {
        output.closeSync();
      }
    } on FileSystemException catch (error) {
      throw _diskError(
        error,
        path: target.path,
        neededBytes: math.max(
          0,
          (length ?? 0) - math.max(0, _lengthOn(target.path)),
        ),
      );
    }
  }

  Future<void> _runJobs(List<SliceJob> jobs) async {
    final queue = Queue.of(jobs);

    Future<void> worker() async {
      while (!_halted && queue.isNotEmpty) {
        await _runJob(queue.removeFirst());
      }
    }

    await Future.wait([
      for (var i = 0; i < math.min(_options.maxConnections, jobs.length); i++)
        worker(),
    ]);

    _throwIfHalted();
  }

  Future<void> _runJob(SliceJob job) async {
    _activeJobs.add(job);

    try {
      final output = job.output = File(
        job.request.savePath,
      ).openSync(mode: job.isResumable ? FileMode.append : FileMode.write);

      output.setPositionSync(job.position);

      var failures = 0;

      while (!job.isComplete) {
        _throwIfHalted();

        final before = job.downloaded;

        try {
          await _fetch(job);

          /// A response without a single byte is a failed attempt too
          failures = job.downloaded > before ? 0 : failures + 1;

          if (failures > _options.maxRetries) {
            throw FilesDownloadError(
              FilesDownloadErrorType.invalidResponse,
              'The server keeps sending no bytes from ${job.position}',
              url: job.request.url,
            );
          }

          if (failures > 0) await _delay(_backoff(failures));
        } on FilesDownloadError catch (error) {
          if (!error.isRetryable) rethrow;

          failures = job.downloaded > before ? 1 : failures + 1;

          if (failures > _options.maxRetries) rethrow;

          if (!job.isResumable) {
            job.restart();
            _setLive(job);
          }

          await _delay(_backoff(failures));
        }
      }

      _saveJob(job);
    } on DownloadStoppedSignal {
      /// The bytes written so far are saved below
    } on FilesDownloadError catch (error) {
      _fail(error);
    } on FileSystemException catch (error) {
      _fail(_diskError(error, path: job.request.savePath));
    } catch (error) {
      _fail(
        FilesDownloadError(
          FilesDownloadErrorType.unknown,
          '$error',
          url: job.request.url,
        ),
      );
    } finally {
      _activeJobs.remove(job);

      try {
        _saveJob(job);
        job.close();
      } on FileSystemException catch (error) {
        _failSaving(error, path: job.request.savePath);
      }
    }
  }

  /// One request of a slice: writes what the server gives
  Future<void> _fetch(SliceJob job) async {
    final file = job.request;
    final range = job.range;
    final position = job.position;
    final headers = {...file.headers};
    var url = file.url;
    var sentIfRange = false;

    if (range != null) {
      switch (file.rangeMode) {
        case RangeRequestMode.header:
          headers['range'] = 'bytes=$position-${range.end}';

          if (file.checkValidator && _isStrongValidator(job.info.validator)) {
            headers['if-range'] = job.info.validator!;
            sentIfRange = true;
          }
        case RangeRequestMode.queryParameter:
          url = _withRangeParameter(url, position, range.end);
      }
    }

    final cancelToken = job.cancelToken = CancelToken();

    if (_halted) cancelToken.cancel();

    final Response<ResponseBody> response;

    try {
      response = await _client.dio.get<ResponseBody>(
        url,
        cancelToken: cancelToken,
        options: Options(headers: headers),
      );
    } on DioException catch (error) {
      throw dioError(error, url);
    }

    final body = response.data!.stream;
    final BodyPlan plan;

    try {
      plan = _planBody(
        job,
        status: response.statusCode ?? 0,
        headers: response.headers,
        url: url,
        sentIfRange: sentIfRange,
      );
    } catch (_) {
      unawaited(body.listen(null, onError: (_) {}).cancel());

      rethrow;
    }

    await _consume(job, body, plan, url);
  }

  /// A weak `ETag` cannot be used with `If-Range`
  static bool _isStrongValidator(String? validator) =>
      validator != null && !validator.startsWith('W/');

  /// googlevideo.com links take the range as `&range=start-end`
  static String _withRangeParameter(String url, int start, int end) =>
      '$url${url.contains('?') ? '&' : '?'}range=$start-$end';

  /// Checks what the server sent against what the slice asked for.
  /// The server may start the part earlier and end it later than asked,
  /// even past the end of the file: the extra bytes are skipped
  BodyPlan _planBody(
    SliceJob job, {
    required int status,
    required Headers headers,
    required String url,
    required bool sentIfRange,
  }) {
    final range = job.range;
    final position = job.position;
    final fileLength = job.info.length;
    final contentLength = RemoteFileProber.contentLengthOf(headers);

    FilesDownloadError invalid(String message) => FilesDownloadError(
      FilesDownloadErrorType.invalidResponse,
      message,
      url: url,
    );

    FilesDownloadError changed(String message) => FilesDownloadError(
      FilesDownloadErrorType.sourceChanged,
      message,
      url: url,
    );

    /// A file without parts: the body is the whole file
    if (range == null) {
      if (status != 200 && status != 206) throw statusError(status, url);

      if (status == 206 &&
          ContentRange.parse(headers.value('content-range'))?.start != 0) {
        throw invalid('The server sent a part instead of the whole file');
      }

      return BodyPlan(skip: 0, take: fileLength);
    }

    final wanted = range.end - position + 1;

    switch (status) {
      case 206:
        final contentRange = ContentRange.parse(headers.value('content-range'));

        if (contentRange == null) {
          /// Without `Content-Range` only a body of exactly the asked
          /// length can be trusted
          if (contentLength == wanted) {
            return BodyPlan(skip: 0, take: wanted, lastPromisedByte: range.end);
          }

          throw invalid(
            'The server sent a part without Content-Range '
            '(${contentLength ?? 'unknown'} bytes, $wanted asked)',
          );
        }

        if (contentRange.total != null &&
            fileLength != null &&
            contentRange.total != fileLength) {
          throw changed(
            'The file is ${contentRange.total} bytes now, '
            'it was $fileLength',
          );
        }

        /// Bytes between the asked position and the part start would be
        /// missing
        if (contentRange.start > position) {
          throw invalid(
            'The server started the part at ${contentRange.start}, '
            '$position was asked',
          );
        }

        final lastByte = [
          contentRange.end,
          range.end,
          if (fileLength != null) fileLength - 1,
        ].reduce(math.min);

        if (lastByte < position) {
          throw invalid(
            'The server sent ${contentRange.start}-${contentRange.end}, '
            'which ends before $position',
          );
        }

        return BodyPlan(
          skip: position - contentRange.start,
          take: lastByte - position + 1,
          lastPromisedByte: lastByte,
        );
      case 200:
        if (job.request.rangeMode == RangeRequestMode.header) {
          if (sentIfRange) {
            throw changed(
              'The file changed on the server: its validator differs',
            );
          }

          if (contentLength != null &&
              fileLength != null &&
              contentLength != fileLength) {
            throw changed(
              'The file is $contentLength bytes now, it was $fileLength',
            );
          }

          /// The server ignored the range and sends the whole file
          return BodyPlan(
            skip: position,
            take: wanted,
            lastPromisedByte: range.end,
          );
        }

        /// The range parameter was ignored: the whole file comes
        if (contentLength != null &&
            contentLength == fileLength &&
            contentLength != wanted) {
          return BodyPlan(
            skip: position,
            take: wanted,
            lastPromisedByte: range.end,
          );
        }

        if (contentLength != null && contentLength > wanted) {
          throw invalid(
            'The server sent $contentLength bytes, $wanted were asked',
          );
        }

        return BodyPlan(
          skip: 0,
          take: wanted,
          lastPromisedByte: contentLength == null
              ? range.end
              : position + contentLength - 1,
        );
      case 416:
        final total = ContentRange.unsatisfiedTotal(
          headers.value('content-range'),
        );

        throw changed(
          'The server has no bytes from $position'
          '${total == null ? '' : ': the file is $total bytes now'}',
        );
      default:
        throw statusError(status, url);
    }
  }

  Future<void> _consume(
    SliceJob job,
    Stream<Uint8List> body,
    BodyPlan plan,
    String url,
  ) async {
    final take = plan.take;
    var skipped = 0;
    var taken = 0;

    try {
      await for (final chunk in body.timeout(_options.idleTimeout)) {
        _throwIfHalted();

        var bytes = chunk;

        if (skipped < plan.skip) {
          final skip = math.min(plan.skip - skipped, bytes.length);

          skipped += skip;

          if (skip == bytes.length) continue;

          bytes = Uint8List.sublistView(bytes, skip);
        }

        if (take != null && bytes.length > take - taken) {
          bytes = Uint8List.sublistView(bytes, 0, take - taken);
        }

        await _delay(_limiter.reserve(bytes.length));

        job.write(bytes);
        taken += bytes.length;
        _meter.add(bytes.length);
        _setLive(job);

        /// The rest of the body is not needed: leaving the loop closes it
        if (take != null && taken >= take) break;
      }
    } catch (error) {
      if (error is DownloadStoppedSignal ||
          _halted ||
          (error is DioException && CancelToken.isCancel(error))) {
        throw const DownloadStoppedSignal();
      }

      throw streamError(error, url) ?? error;
    }

    if (take == null) {
      /// The whole body of a file of an unknown size is here
      job.finished = true;

      return;
    }

    if (taken >= take) {
      if (!job.isResumable) job.finished = true;

      return;
    }

    final promised = plan.lastPromisedByte;

    /// The server promised less than the slice needs and kept its word:
    /// the next request asks for the rest
    if (job.isResumable && promised != null && job.position > promised) {
      return;
    }

    throw FilesDownloadError(
      FilesDownloadErrorType.network,
      'The connection closed after ${skipped + taken} of '
      '${plan.skip + take} bytes',
      url: url,
    );
  }

  void _setLive(SliceJob job) {
    final counters = _live[job.file];

    if (job.slice < counters.length) counters[job.slice] = job.downloaded;
  }

  /// Flushes the written bytes of a slice and puts them into the state
  void _saveJob(SliceJob job) {
    final state = _state;

    job.flush();

    if (state == null || !job.isResumable) return;

    state.setCounter(job.file, job.slice, job.durable);
  }

  void _checkpoint() {
    final state = _state;

    if (state == null) return;

    try {
      for (final job in _activeJobs) {
        _saveJob(job);
      }

      state.flushSync();
    } on FileSystemException catch (error) {
      _failSaving(error, path: error.path ?? statePath);
    }
  }

  int? get _totalBytes {
    if (_infos.isEmpty) return _previousState?.snapshot().totalBytes;

    return _infos.any((info) => info.length == null)
        ? null
        : _infos.fold<int>(0, (sum, info) => sum + info.length!);
  }

  /// What a previous state claims, but only as far as the files on disk
  /// still hold it: a deleted or shortened file does not show old progress
  List<int> _bytesOnDisk(DownloadStateFile? previous) {
    final files = previous?.snapshot().files ?? const [];

    return [
      for (var file = 0; file < _files.length; file++)
        switch (files.elementAtOrNull(file)) {
          final saved? when saved.identity == _files[file].identity =>
            saved.downloadedBytesWithin(_lengthOnDisk(_files[file].savePath)),
          _ => 0,
        },
    ];
  }

  static int _lengthOnDisk(String path) {
    final file = File(path);

    return file.existsSync() ? file.lengthSync() : 0;
  }

  int _fileBytes(int file) => _live.isEmpty
      ? _previousBytes.elementAtOrNull(file) ?? 0
      : _live.elementAtOrNull(file)?.fold<int>(0, (a, b) => a + b) ?? 0;

  int get _downloadedBytes => [
    for (var file = 0; file < _files.length; file++) _fileBytes(file),
  ].fold(0, (a, b) => a + b);

  void _emitProgress() {
    final state = _state;

    _onProgress(
      FilesDownloadProgress(
        id: request.id,
        stage: _stage,
        downloadedBytes: _downloadedBytes,
        totalBytes: _totalBytes,
        bytesPerSecond: _stage == FilesDownloadStage.downloading
            ? _meter.bytesPerSecond
            : null,
        activeConnections: _activeJobs.length,
        files: [
          for (var file = 0; file < _files.length; file++)
            FileDownloadProgress(
              savePath: _files[file].savePath,
              downloadedBytes: _fileBytes(file),
              totalBytes: _infos.isEmpty ? null : _infos[file].length,
              completedSlices: _completedSlices(file),
              sliceCount: state?.sliceCount(file) ?? 0,
            ),
        ],
      ),
    );
  }

  int _completedSlices(int file) {
    final state = _state;

    final live = _live.elementAtOrNull(file);

    if (state == null || live == null) return 0;

    var completed = 0;

    for (var slice = 0; slice < state.sliceCount(file); slice++) {
      final range = state.sliceRange(file, slice);
      final bytes = live.elementAtOrNull(slice) ?? 0;

      if (range != null && bytes >= range.length) completed++;
    }

    return completed;
  }

  FilesDownloadResult _finish() {
    final state = _state;
    final failure = _failure;

    try {
      _checkpoint();

      if (failure != null) {
        /// A changed file cannot be continued: the next start begins anew
        _releaseState(
          state,
          delete: failure.type == FilesDownloadErrorType.sourceChanged,
        );
        _emitProgress();

        return FilesDownloadFailed(
          request.id,
          error: failure,
          downloadedBytes: _downloadedBytes,
        );
      }

      if (_stopped) {
        if (_discard) {
          state?.deleteSync();

          final stateFile = File(statePath);

          if (stateFile.existsSync()) stateFile.deleteSync();

          for (final file in _files) {
            final target = File(file.savePath);

            if (target.existsSync()) target.deleteSync();
          }

          return FilesDownloadStopped(
            request.id,
            downloadedBytes: 0,
            totalBytes: _totalBytes,
            discarded: true,
          );
        }

        state?.closeSync();
        _emitProgress();

        if (_saveFailure case final saveFailure?) {
          return FilesDownloadFailed(
            request.id,
            error: saveFailure,
            downloadedBytes: _downloadedBytes,
          );
        }

        return FilesDownloadStopped(
          request.id,
          downloadedBytes: _downloadedBytes,
          totalBytes: _totalBytes,
        );
      }

      _stage = FilesDownloadStage.finishing;
      _emitProgress();

      final downloaded = [
        for (var file = 0; file < _files.length; file++) _verify(file),
      ];

      if (_options.deleteStateOnComplete) {
        state?.deleteSync();
      } else {
        state?.closeSync();
      }

      _emitProgress();

      return FilesDownloadCompleted(request.id, files: downloaded);
    } on FileSystemException catch (error) {
      return FilesDownloadFailed(
        request.id,
        error: _diskError(error),
        downloadedBytes: _downloadedBytes,
      );
    } catch (error) {
      /// The result always comes: the isolate never ends with a raw error
      return FilesDownloadFailed(
        request.id,
        error: _failure ?? _unexpected(error),
        downloadedBytes: 0,
      );
    } finally {
      /// Nothing leaves the state open, not even a failed file check
      _releaseState(state, delete: false);
    }
  }

  /// Closes or deletes the state. A failure here does not replace the result
  /// the download already has: the state file just stays as it is
  static void _releaseState(DownloadStateFile? state, {required bool delete}) {
    try {
      if (delete) {
        state?.deleteSync();
      } else {
        state?.closeSync();
      }
    } on FileSystemException {
      /// The next start checks the state anyway
    }
  }

  /// A finished file is exactly as long as the server said
  DownloadedFile _verify(int file) {
    final target = File(_files[file].savePath);
    final length = _infos[file].length;
    final actual = target.lengthSync();

    if (length != null && actual != length) {
      if (actual < length) {
        throw FileSystemException(
          'The file is shorter than downloaded ($actual of $length bytes)',
          target.path,
        );
      }

      final output = target.openSync(mode: FileMode.append);

      try {
        output.truncateSync(length);
      } finally {
        output.closeSync();
      }
    }

    return DownloadedFile(path: target.path, length: length ?? actual);
  }
}
