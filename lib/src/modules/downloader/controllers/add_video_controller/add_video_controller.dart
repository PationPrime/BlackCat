import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/failure/failure.dart';
import 'package:youtube_downloader/src/app/logger/app_logger.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/operation_result/operation_result.dart';
import 'package:youtube_downloader/src/app/repositories/repositories.dart';
import 'package:youtube_downloader/src/app/shared_controllers/shared_controllers.dart';
import 'package:youtube_downloader/src/app/tools/tools.dart';

part 'add_video_state.dart';

/// Add video dialog: search by link and quality selection.
///
/// yt-dlp searches first; when yt-dlp itself fails (not the video),
/// the built-in downloader searches instead
class AddVideoController extends Cubit<AddVideoState> {
  static const _appLogger = AppLogger(where: 'AddVideoController');

  final VideoRepositoryInterface _videoRepository;
  final YtDlpVideoRepositoryInterface _ytDlpVideoRepository;
  final AuthorizationController _authorizationController;

  AddVideoController({
    required this._videoRepository,
    required this._ytDlpVideoRepository,
    required this._authorizationController,
  }) : super(const AddVideoInitialState());

  void _safeEmit(AddVideoState state) {
    if (isClosed) return;

    emit(state);
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

  /// An error from another controller to show in the dialog
  void showFailure(Failure failure) {
    _safeEmit(state.copyWith(failure: failure));
  }
}
