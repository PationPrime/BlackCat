import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:black_cat/src/app/errors/errors.dart';
import 'package:black_cat/src/app/failure/failure.dart';
import 'package:black_cat/src/app/logger/app_logger.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/operation_result/operation_result.dart';
import 'package:black_cat/src/app/repositories/repositories.dart';
import 'package:black_cat/src/app/shared_controllers/shared_controllers.dart';
import 'package:black_cat/src/app/tools/tools.dart';

part 'add_video_state.dart';

/// Video search on the home page: search by link and quality selection.
///
/// yt-dlp searches first; when yt-dlp itself fails (not the video),
/// the built-in downloader searches instead. A search that needed signing in
/// repeats once cookies are imported
class AddVideoController extends Cubit<AddVideoState> {
  static const _appLogger = AppLogger(where: 'AddVideoController');

  final VideoRepositoryInterface _videoRepository;
  final YtDlpVideoRepositoryInterface _ytDlpVideoRepository;
  final AuthorizationController _authorizationController;

  late final StreamSubscription<AuthorizationState> _authorizationSubscription;
  AccountSessionModel? _session;

  AddVideoController({
    required this._videoRepository,
    required this._ytDlpVideoRepository,
    required this._authorizationController,
  }) : super(const AddVideoInitialState()) {
    _session = _authorizationController.state.session;
    _authorizationSubscription = _authorizationController.stream.listen(
      _onAuthorizationChanged,
    );
  }

  void _safeEmit(AddVideoState state) {
    if (isClosed) return;

    emit(state);
  }

  @override
  Future<void> close() async {
    /// Not awaited: the cancel future belongs to the root zone and never
    /// completes inside fake async zones of widget tests
    unawaited(_authorizationSubscription.cancel());

    await super.close();
  }

  /// Cookies imported in the settings may lift the sign-in requirement.
  /// Signing in through the window repeats the search on its own
  void _onAuthorizationChanged(AuthorizationState authorizationState) {
    final previousSession = _session;
    final session = _session = authorizationState.session;

    if (session == null || !session.isImported || session == previousSession) {
      return;
    }

    if (state.failure case VideoFailure(needsSignIn: true)) {
      unawaited(retry());
    }
  }

  VideoRepositoryInterface _videoRepositoryOf(DownloadEngineModel engine) =>
      switch (engine) {
        DownloadEngineModel.builtIn => _videoRepository,
        DownloadEngineModel.ytDlp => _ytDlpVideoRepository,
      };

  /// Finds the video with [engine]: the video is downloaded with the engine
  /// that found it
  Future<void> fetchVideoInfo(
    String url, {
    DownloadEngineModel engine = DownloadEngineModel.fallback,
  }) async {
    if (url.trim().isEmpty || state.isInfoLoading) {
      return;
    }

    _safeEmit(
      state.copyWith(
        requestedUrl: url,
        requestedEngine: engine,
        engine: engine,
        isInfoLoading: true,
        clearVideoInfo: true,
        clearAddedVideo: true,
        clearFailure: true,
      ),
    );

    var videoInfoResponse = await _videoRepositoryOf(engine).getVideoInfo(url);

    if (engine == DownloadEngineModel.ytDlp &&
        _isYtDlpFailure(videoInfoResponse.failure)) {
      _appLogger.logFailure(
        videoInfoResponse.failure!,
        'yt-dlp failed, searching with the built-in downloader',
      );

      _safeEmit(state.copyWith(engine: DownloadEngineModel.builtIn));

      videoInfoResponse = await _videoRepository.getVideoInfo(url);
    }

    if (videoInfoResponse.isFailed) {
      final failure = videoInfoResponse.failure ?? const OtherFailure();

      _appLogger.logFailure(failure, 'Failed to get video info');

      _safeEmit(state.copyWith(isInfoLoading: false, failure: failure));

      return;
    }

    final videoInfo = videoInfoResponse.requireData;

    _safeEmit(
      state.copyWith(
        isInfoLoading: false,
        videoInfo: videoInfo,
        selectedQualityId: QualitySelector.pickDefaultQuality(
          videoInfo.qualities,
        ),
      ),
    );
  }

  /// yt-dlp is missing or broke on its own: the built-in downloader may
  /// still find the video. Video errors (sign-in, private…) are final
  static bool _isYtDlpFailure(Failure? failure) {
    const codes = VideoErrorCodes();

    return failure?.code == codes.ytDlpNotFound ||
        failure?.code == codes.ytDlpFailed;
  }

  void selectQuality(String qualityId) {
    _safeEmit(state.copyWith(selectedQualityId: qualityId));
  }

  /// Signing in to YouTube (or refreshing the sign-in) and retrying the search
  Future<void> signInAndRetry() async {
    if (!await _authorizationController.signIn()) {
      return;
    }

    await retry();
  }

  /// Repeats the last search, e.g. after importing cookies
  Future<void> retry() =>
      fetchVideoInfo(state.requestedUrl, engine: state.requestedEngine);

  /// The found video went to the downloads: the form is ready for the next
  /// one and remembers the added video for a confirmation
  void completeAdding() {
    final video = state.videoInfo;

    if (video == null) return;

    _safeEmit(AddVideoState(addedVideo: video));
  }

  /// Clears the search and its result
  void clear() {
    if (state.isInfoLoading) return;

    _safeEmit(const AddVideoInitialState());
  }

  void dismissAddedVideo() {
    _safeEmit(state.copyWith(clearAddedVideo: true));
  }

  /// An error from another controller to show on the page
  void showFailure(Failure failure) {
    _safeEmit(state.copyWith(failure: failure));
  }
}
