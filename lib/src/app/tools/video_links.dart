import '../models/models.dart';
import 'rutube_url_parser.dart';
import 'youtube_url_parser.dart';

abstract final class VideoLinks {
  /// Site of a video link. `null` for a link the app cannot download
  static VideoSourceModel? sourceOf(String? url) {
    if (YouTubeUrlParser.parse(url) != null) return VideoSourceModel.youtube;
    if (RuTubeUrlParser.parse(url) != null) return VideoSourceModel.rutube;

    return null;
  }
}
