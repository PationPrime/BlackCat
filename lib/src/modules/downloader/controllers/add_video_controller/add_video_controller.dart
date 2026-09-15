import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:youtube_downloader/src/app/failure/failure.dart';
import 'package:youtube_downloader/src/app/logger/app_logger.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/operation_result/operation_result.dart';
import 'package:youtube_downloader/src/app/repositories/repositories.dart';
import 'package:youtube_downloader/src/app/shared_controllers/shared_controllers.dart';
import 'package:youtube_downloader/src/app/tools/tools.dart';

part 'add_video_state.dart';

/// Add video dialog: search by link and quality selection
class AddVideoController extends Cubit<AddVideoState> {
  static const _appLogger = AppLogger(where: 'AddVideoController');

  final VideoRepositoryInterface _videoRepository;
  final AuthorizationController _authorizationController;

  AddVideoController({
    required this._videoRepository,
    required this._authorizationController,
  }) : super(const AddVideoInitialState());

  void _safeEmit(AddVideoState state) {
    if (isClosed) return;

    emit(state);
  }

  Future<void> fetchVideoInfo(String url) async {
    if (url.trim().isEmpty || state.isInfoLoading) {
      return;
    }

    _safeEmit(
      state.copyWith(
        requestedUrl: url,
        isInfoLoading: true,
        clearVideoInfo: true,
        clearFailure: true,
      ),
    );

    final videoInfoResponse = await _videoRepository.getVideoInfo(url);

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

  void selectQuality(String qualityId) {
    _safeEmit(state.copyWith(selectedQualityId: qualityId));
  }

  /// Signing in to YouTube (or refreshing the sign-in) and retrying the search
  Future<void> signInAndRetry() async {
    if (!await _authorizationController.signIn()) {
      return;
    }

    await fetchVideoInfo(state.requestedUrl);
  }

  /// An error from another controller to show in the dialog
  void showFailure(Failure failure) {
    _safeEmit(state.copyWith(failure: failure));
  }
}
