/// Resumable HTTP downloads of any files in slices, in a background isolate.
///
/// A file is split into slices that are downloaded in parallel with range
/// requests, like torrent pieces. Progress of every slice of every file
/// of a download lives in one binary state file, `state_<id>.fds`, so
/// a paused or interrupted download continues where it stopped
library;

export 'src/engine/download_api_client.dart' show DownloadApiClient;
export 'src/engine/download_engine.dart' show DownloadEngine;
export 'src/files_downloader.dart';
export 'src/models/byte_ranges.dart';
export 'src/models/download_error.dart';
export 'src/models/download_options.dart';
export 'src/models/download_progress.dart';
export 'src/models/download_request.dart';
export 'src/models/download_result.dart';
export 'src/models/remote_file_info.dart';
export 'src/models/segments_request.dart';
export 'src/state/download_state_snapshot.dart';
export 'src/storage/disk_space.dart';
