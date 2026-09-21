import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:black_cat/src/app/constants/constants.dart';
import 'package:black_cat/src/app/errors/errors.dart';
import 'package:black_cat/src/app/failure/failure.dart';
import 'package:black_cat/src/app/logger/app_logger.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/operation_result/operation_result.dart';
import 'package:black_cat/src/app/repositories/repositories.dart';
import 'package:black_cat/src/app/shared_controllers/shared_controllers.dart';

part 'video_library_state.dart';

/// Videos of the download folder for the player.
///
/// The list follows the folder: files that appear or disappear show up
/// on their own, and a folder changed in the settings is read anew.
/// Thumbnails and durations the system knows are loaded one by one after
/// the list is shown
final class VideoLibraryController extends Cubit<VideoLibraryState> {
  static const _appLogger = AppLogger(where: 'VideoLibraryController');

  final VideoLibraryRepositoryInterface _videoLibraryRepository;
  final SettingsController _settingsController;

  /// Changes in the folder are gathered for this time before it is read
  final Duration _folderChangesDebounce;

  late final StreamSubscription<SettingsState> _settingsSubscription;
  StreamSubscription<void>? _folderSubscription;
  Timer? _folderChangesTimer;

  /// Only the newest reading of the folder shows its result
  var _syncGeneration = 0;
  var _isLoadingMetadata = false;

  /// Videos the system could not describe: not asked again until
  /// the next launch
  final _metadataFailures = <String>{};

  VideoLibraryController({
    required this._videoLibraryRepository,
    required this._settingsController,
    this._folderChangesDebounce = PlayerConstants.folderChangesDebounce,
  }) : super(const VideoLibraryInitialState()) {
    _settingsSubscription = _settingsController.stream.listen(
      (settings) => _openFolder(settings.downloadDirectory?.path),
    );
  }

  void _safeEmit(VideoLibraryState state) {
    if (isClosed) return;

    emit(state);
  }

  @override
  Future<void> close() async {
    _folderChangesTimer?.cancel();

    /// Cancelling may wait for the platform: the controller closes anyway
    unawaited(_settingsSubscription.cancel());
    unawaited(_folderSubscription?.cancel());

    await super.close();
  }

  /// Reads the download folder and starts following it. Until the settings
  /// are loaded the list stays in loading
  Future<void> load() =>
      _openFolder(_settingsController.state.downloadDirectory?.path);

  Future<void> _openFolder(String? folder) async {
    if (folder == null) return;

    if (folder != state.folder) {
      _folderChangesTimer?.cancel();
      unawaited(_folderSubscription?.cancel());
      _folderSubscription = null;

      /// Videos of the previous folder are not shown in the new one
      _safeEmit(VideoLibraryState(folder: folder, isLoading: true));
    }

    await refresh();
  }

  /// Reads the folder again: new, replaced and deleted files
  Future<void> refresh() async {
    final folder = state.folder;

    if (folder == null || isClosed) return;

    _folderSubscription ??= _watch(folder);

    final generation = ++_syncGeneration;
    final response = await _videoLibraryRepository.syncVideos(folder);

    if (generation != _syncGeneration || folder != state.folder) return;

    if (response.isFailed) {
      final failure = response.failure ?? const OtherFailure();
      final folderMissing =
          failure.code == const PlayerErrorCodes().folderNotFound;

      _appLogger.logFailure(failure, 'Failed to read the download folder');

      _safeEmit(
        state.copyWith(
          isLoading: false,

          /// Videos of a missing folder cannot be played
          videos: folderMissing ? const [] : null,
          failure: failure,
        ),
      );

      return;
    }

    _safeEmit(
      state.copyWith(
        isLoading: false,
        videos: _merged(response.requireData),
        clearFailure: true,
      ),
    );

    unawaited(_loadMissingMetadata());
  }

  StreamSubscription<void> _watch(String folder) {
    late final StreamSubscription<void> subscription;

    subscription = _videoLibraryRepository
        .watchFolder(folder)
        .listen(
          (_) => _scheduleRefresh(),
          onError: (Object error, StackTrace stackTrace) => _appLogger.logError(
            'Stopped following the download folder: $error',
            stackTrace: stackTrace,
          ),
          onDone: () {
            /// The folder is followed again on the next reading
            if (identical(_folderSubscription, subscription)) {
              _folderSubscription = null;
            }
          },
          cancelOnError: true,
        );

    return subscription;
  }

  /// A download or a copy changes the folder many times in a row
  void _scheduleRefresh() {
    _folderChangesTimer?.cancel();
    _folderChangesTimer = Timer(_folderChangesDebounce, refresh);
  }

  /// A reading that started before a watch position or a thumbnail was saved
  /// returns them older than the screen already shows
  List<LibraryVideoModel> _merged(List<LibraryVideoModel> fresh) {
    final known = {for (final video in state.videos) video.id: video};

    return [
      for (final video in fresh)
        switch (known[video.id]) {
          final current?
              when current.modifiedAt.isAtSameMomentAs(video.modifiedAt) =>
            LibraryVideoModel(
              id: video.id,
              path: video.path,
              title: video.title,
              sizeBytes: video.sizeBytes,
              modifiedAt: video.modifiedAt,
              duration: video.duration ?? current.duration,
              position: _isNewer(current.watchedAt, video.watchedAt)
                  ? current.position
                  : video.position,
              thumbnailPath: video.thumbnailPath ?? current.thumbnailPath,
              isMetadataLoaded:
                  video.isMetadataLoaded || current.isMetadataLoaded,
              watchedAt: _isNewer(current.watchedAt, video.watchedAt)
                  ? current.watchedAt
                  : video.watchedAt,
            ),
          _ => video,
        },
    ];
  }

  static bool _isNewer(DateTime? left, DateTime? right) =>
      left != null && (right == null || left.isAfter(right));

  /// One video at a time, the newest first: the top of the list fills first
  Future<void> _loadMissingMetadata() async {
    if (_isLoadingMetadata) return;

    _isLoadingMetadata = true;

    try {
      while (!isClosed) {
        final video = state.videos
            .where(
              (video) =>
                  !video.isMetadataLoaded &&
                  !_metadataFailures.contains(video.id),
            )
            .firstOrNull;

        if (video == null) return;

        final response = await _videoLibraryRepository.loadMetadata(video);

        if (response.isFailed) {
          _metadataFailures.add(video.id);
          _appLogger.logFailure(
            response.failure ?? const OtherFailure(),
            'Failed to read the video thumbnail and duration',
          );

          continue;
        }

        final loaded = response.requireData;

        _replace(
          loaded.id,
          (current) => current.modifiedAt.isAtSameMomentAs(loaded.modifiedAt)
              ? current.copyWith(
                  duration: current.duration ?? loaded.duration,
                  thumbnailPath: loaded.thumbnailPath,
                  isMetadataLoaded: true,
                )
              : current,
        );
      }
    } finally {
      _isLoadingMetadata = false;
    }
  }

  void _replace(
    String videoId,
    LibraryVideoModel Function(LibraryVideoModel video) change,
  ) => _safeEmit(
    state.copyWith(
      videos: [
        for (final video in state.videos)
          video.id == videoId ? change(video) : video,
      ],
    ),
  );

  /// Remembers where the user stopped watching. [duration] of the player
  /// is more exact than the one of the download
  Future<void> savePosition(
    String videoId, {
    required Duration position,
    Duration? duration,
  }) async {
    final video = state.videos
        .where((video) => video.id == videoId)
        .firstOrNull;

    /// The file is gone: its video is no longer in the library
    if (video == null) return;

    final saved = video.copyWith(
      position: position,
      duration: duration != null && duration > Duration.zero
          ? duration
          : video.duration,
      watchedAt: DateTime.now(),
    );

    _replace(videoId, (_) => saved);

    final response = await _videoLibraryRepository.savePosition(saved);

    if (response.isFailed) {
      _appLogger.logFailure(
        response.failure ?? const OtherFailure(),
        'Failed to save the watch position',
      );
    }
  }

  void showFailure(Failure failure) =>
      _safeEmit(state.copyWith(failure: failure));

  void dismissFailure() => _safeEmit(state.copyWith(clearFailure: true));
}
