import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:youtube_downloader/src/app/failure/failure.dart';
import 'package:youtube_downloader/src/app/logger/app_logger.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/operation_result/operation_result.dart';
import 'package:youtube_downloader/src/app/repositories/repositories.dart';
import 'package:youtube_downloader/src/app/shared_controllers/shared_controllers.dart';
import 'package:youtube_downloader/src/app/tools/tools.dart';

part 'downloader_state.dart';

/// Поиск видео по ссылке, выбор качества и загрузка в «Загрузки»
class DownloaderController extends Cubit<DownloaderState> {
  static const _appLogger = AppLogger(where: 'DownloaderController');

  final VideoRepositoryInterface _videoRepository;
  final AuthorizationController _authorizationController;

  DownloaderController({
    required this._videoRepository,
    required this._authorizationController,
  }) : super(const DownloaderInitialState());

  void _safeEmit(DownloaderState state) {
    if (isClosed) return;

    emit(state);
  }

  Future<void> fetchVideoInfo(String url) async {
    if (url.trim().isEmpty || !state.canSearch) {
      return;
    }

    _safeEmit(
      state.copyWith(
        requestedUrl: url,
        isInfoLoading: true,
        clearVideoInfo: true,
        clearJob: true,
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
    if (state.isJobActive) {
      return;
    }

    _safeEmit(state.copyWith(selectedQualityId: qualityId, clearJob: true));
  }

  Future<void> download() async {
    final videoInfo = state.videoInfo;

    if (videoInfo == null || !state.canDownload || state.isJobActive) {
      return;
    }

    _safeEmit(
      state.copyWith(
        job: const DownloadJob(
          status: DownloadJobStatus.downloading,
          percent: 0,
        ),
        clearFailure: true,
      ),
    );

    final downloadResponse = await _videoRepository.downloadVideo(
      url: videoInfo.url,
      quality: state.selectedQualityId,
      onProgress: (progress) => _safeEmit(
        state.copyWith(
          job: DownloadJob(
            status: progress.stage.isProcessing
                ? DownloadJobStatus.processing
                : DownloadJobStatus.downloading,
            percent: progress.percent,
            speed: progress.speed,
            eta: progress.eta,
          ),
        ),
      ),
    );

    if (downloadResponse.isFailed) {
      final failure = downloadResponse.failure ?? const OtherFailure();

      _appLogger.logFailure(failure, 'Failed to download video');

      _safeEmit(state.copyWith(clearJob: true, failure: failure));

      return;
    }

    _safeEmit(
      state.copyWith(
        job: DownloadJob(
          status: DownloadJobStatus.done,
          percent: 100,
          filePath: downloadResponse.requireData,
        ),
      ),
    );
  }

  /// Вход в YouTube (или обновление входа) и повтор того, что не получилось
  Future<void> signInAndRetry() async {
    if (!await _authorizationController.signIn()) {
      return;
    }

    if (state.videoInfo != null) {
      await download();
    } else {
      await fetchVideoInfo(state.requestedUrl);
    }
  }

  /// Ошибка другого контроллера, которую нужно показать на экране
  void showFailure(Failure failure) {
    _safeEmit(state.copyWith(failure: failure));
  }
}
