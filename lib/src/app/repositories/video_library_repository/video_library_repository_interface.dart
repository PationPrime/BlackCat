import '../../models/models.dart';
import '../../operation_result/operation_result.dart';
import '../base_repository_interface.dart';

/// Player library: videos of the download folder and where the user
/// stopped watching them
abstract interface class VideoLibraryRepositoryInterface
    implements BaseRepositoryInterface {
  /// Videos of [folder], the newest first. The library follows the folder:
  /// a new file is added with the title, duration and thumbnail of its
  /// download if the app downloaded it, a replaced file is read anew,
  /// and a video whose file is gone is deleted with its thumbnail.
  ///
  /// A missing folder fails and leaves the library as it is: the drive
  /// may just be unplugged
  Future<OperationResult<List<LibraryVideoModel>>> syncVideos(String folder);

  /// Asks the system for the thumbnail and duration the video lacks
  Future<OperationResult<LibraryVideoModel>> loadMetadata(
    LibraryVideoModel video,
  );

  /// Saves where the user stopped watching and the duration once known
  Future<OperationResult<void>> savePosition(LibraryVideoModel video);

  /// Deletes the video file from the device for good, then the video
  /// from the library with its thumbnail. Returns the ids of the downloads
  /// of the file: the download list forgets them.
  ///
  /// A file the system keeps fails and leaves everything as it is
  Future<OperationResult<List<String>>> deleteVideo(LibraryVideoModel video);

  /// Emits when a video file of [folder] appears, changes or disappears
  Stream<void> watchFolder(String folder);
}
