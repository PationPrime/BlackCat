import 'package:path/path.dart' as p;

import '../models/models.dart';

/// Format of unfinished files in the download work folder.
///
/// Each stream is written into its own `<role>-<itag>-<size>.part` file, e.g.
/// `video-137-52428800.part`. Bytes in the file go in order from the stream start,
/// so the file length is exactly the place the download continues from.
/// The name shows which stream the file belongs to: if YouTube returns
/// other streams on resume, old files are not picked up by mistake
abstract final class DownloadPartFiles {
  static const _extension = '.part';

  /// Muxed file before it is moved to the download folder
  static const outputBaseName = 'output';

  static final _namePattern = RegExp(r'^(video|audio)-(\d+)-(\d+)\.part$');

  static String fileName(DownloadStreamModel stream) =>
      '${stream.role.name}-${stream.itag}-${stream.contentLength}$_extension';

  static String path(String workDirectory, DownloadStreamModel stream) =>
      p.join(workDirectory, fileName(stream));

  /// Stream from the file name; `null` for foreign files
  static DownloadStreamModel? parse(String fileName) {
    final match = _namePattern.firstMatch(fileName);

    if (match == null) return null;

    return DownloadStreamModel(
      role: DownloadStreamRole.values.byName(match.group(1)!),
      itag: int.parse(match.group(2)!),
      contentLength: int.parse(match.group(3)!),
    );
  }

  /// Downloaded bytes of the stream by its file length. A file longer than the stream
  /// is not from this stream: the download starts it over
  static int resumableBytes(int fileLength, DownloadStreamModel stream) =>
      fileLength > stream.contentLength ? 0 : fileLength;
}
