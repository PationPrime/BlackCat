import 'video_repository_interface.dart';

/// Getting and downloading videos with yt-dlp. The app prefers it once
/// yt-dlp and a JavaScript runtime are installed
abstract interface class YtDlpVideoRepositoryInterface
    implements VideoRepositoryInterface {}
