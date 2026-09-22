import 'dart:isolate';

import '../engine/download_api_client.dart';
import '../engine/download_engine.dart';
import '../engine/segments_engine.dart';
import '../engine/worker_engine.dart';
import '../models/download_error.dart';
import '../models/download_options.dart';
import '../models/download_request.dart';
import '../models/download_result.dart';
import '../models/segments_request.dart';

/// What the download isolate starts with: a [FilesDownloadRequest]
/// or a [SegmentsDownloadRequest]
final class WorkerBoot {
  final SendPort host;
  final Object request;

  const WorkerBoot({required this.host, required this.request});

  String get id => switch (request) {
    FilesDownloadRequest(:final id) || SegmentsDownloadRequest(:final id) => id,
    _ => throw ArgumentError.value(request, 'request'),
  };

  FilesDownloadOptions get options => switch (request) {
    FilesDownloadRequest(:final options) ||
    SegmentsDownloadRequest(:final options) => options,
    _ => throw ArgumentError.value(request, 'request'),
  };
}

/// Stops the download; [discard] deletes its files and state
final class WorkerStopCommand {
  final bool discard;

  const WorkerStopCommand({required this.discard});
}

final class WorkerSpeedLimitCommand {
  final int? bytesPerSecond;

  const WorkerSpeedLimitCommand(this.bytesPerSecond);
}

/// Entry of the download isolate. Sends the host its command port first,
/// then progress, and exits with the result
Future<void> runDownloadWorker(WorkerBoot boot) async {
  final commands = ReceivePort();
  final client = DownloadApiClient(boot.options);
  final WorkerEngine engine = switch (boot.request) {
    final SegmentsDownloadRequest request => SegmentsDownloadEngine(
      request: request,
      client: client,
      onProgress: boot.host.send,
    ),
    final FilesDownloadRequest request => DownloadEngine(
      request: request,
      client: client,
      onProgress: boot.host.send,
    ),
    final request => throw ArgumentError.value(request, 'request'),
  };

  commands.listen(
    (command) => switch (command) {
      WorkerStopCommand(:final discard) => engine.stop(discard: discard),
      WorkerSpeedLimitCommand(:final bytesPerSecond) => engine.setSpeedLimit(
        bytesPerSecond,
      ),
      _ => null,
    },
  );

  boot.host.send(commands.sendPort);

  FilesDownloadResult result;

  try {
    result = await engine.run();
  } catch (error) {
    /// A bug in the engine still ends with a result, not with a dead isolate
    result = FilesDownloadFailed(
      boot.id,
      error: FilesDownloadError(FilesDownloadErrorType.unknown, '$error'),
      downloadedBytes: 0,
    );
  }

  commands.close();
  client.close();

  Isolate.exit(boot.host, result);
}
