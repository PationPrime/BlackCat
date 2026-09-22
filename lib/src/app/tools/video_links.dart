import '../models/models.dart';
import 'instagram_url_parser.dart';
import 'rutube_url_parser.dart';
import 'tiktok_url_parser.dart';
import 'youtube_url_parser.dart';

abstract final class VideoLinks {
  /// Site of a video link. `null` for a link the app cannot download
  static VideoSourceModel? sourceOf(String? url) {
    if (YouTubeUrlParser.parse(url) != null) return VideoSourceModel.youtube;
    if (RuTubeUrlParser.parse(url) != null) return VideoSourceModel.rutube;
    if (TikTokUrlParser.parse(url) != null) return VideoSourceModel.tiktok;
    if (InstagramUrlParser.parse(url) != null) {
      return VideoSourceModel.instagram;
    }

    return null;
  }
}
