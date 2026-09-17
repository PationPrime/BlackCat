import 'dart:isolate';

import '../engine/download_api_client.dart';
import '../engine/download_engine.dart';
import '../models/download_request.dart';

/// What the download isolate starts with
final class WorkerBoot {
  final SendPort host;
  final FilesDownloadRequest request;

  const WorkerBoot({required this.host, required this.request});
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
  final client = DownloadApiClient(boot.request.options);
  final engine = DownloadEngine(
    request: boot.request,
    client: client,
    onProgress: boot.host.send,
  );

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

  final result = await engine.run();

  commands.close();
  client.close();

  Isolate.exit(boot.host, result);
}
