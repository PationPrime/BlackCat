/// A RuTube video from the player API: what its page shows and where
/// its HLS playlist is
class RuTubeVideoDto {
  final String id;
  final String title;
  final String? author;

  /// Duration in seconds
  final num? durationSeconds;
  final String? thumbnail;

  /// HLS master playlist: the qualities of the video
  final Uri masterPlaylist;

  const RuTubeVideoDto({
    required this.id,
    required this.title,
    required this.masterPlaylist,
    this.author,
    this.durationSeconds,
    this.thumbnail,
  });
}
