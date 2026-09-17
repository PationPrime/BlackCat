abstract final class PlayerConstants {
  /// Files the player library lists from the download folder
  static const videoExtensions = {
    '.mp4',
    '.m4v',
    '.mkv',
    '.webm',
    '.mov',
    '.avi',
    '.wmv',
    '.flv',
  };

  /// Seeking with the buttons, J / L, the arrows and a double tap
  static const seekStep = Duration(seconds: 10);

  /// Playback speeds of the speed menu; the first one is the normal speed
  static const playbackRates = [1.0, 1.25, 1.5, 2.0];

  /// Share of the window the player dialog takes outside of full screen
  static const dialogWindowFraction = 0.8;

  /// A double tap this close to the left or right edge (as a share
  /// of the player width) seeks back or forward
  static const seekZoneFraction = 0.35;

  /// A second tap within this time makes a double tap
  static const doubleTapTimeout = Duration(milliseconds: 300);

  /// After a double tap on an edge, every tap on it within this time
  /// seeks once more, as on YouTube
  static const seekStreakTimeout = Duration(milliseconds: 800);

  /// Controls hide after this time without the pointer moving
  static const controlsHideDelay = Duration(seconds: 3);

  /// The playback position is shown no more often
  static const positionUpdateInterval = Duration(milliseconds: 100);

  /// The watch position is saved to the database no more often while playing
  static const positionSaveInterval = Duration(seconds: 5);

  /// Volume change of the up and down arrows
  static const volumeStep = 0.05;

  /// A video stopped this close to its start or end opens from the beginning
  static const resumeMargin = Duration(seconds: 5);

  /// Biggest size of the thumbnails the system file manager gives
  static const thumbnailWidth = 640;
  static const thumbnailHeight = 360;

  /// Changes in the download folder are gathered for this time
  /// before the library is read again
  static const folderChangesDebounce = Duration(milliseconds: 500);
}
