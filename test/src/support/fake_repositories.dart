import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/operation_result/operation_result.dart';
import 'package:youtube_downloader/src/app/repositories/repositories.dart';

class FakeVideoRepository implements VideoRepositoryInterface {
  final List<OperationResult<VideoInfoModel>> infoResults;
  final List<OperationResult<String>> downloadResults;
  final List<DownloadProgressModel> progressToReport;

  /// Загрузка не завершится, пока тест не завершит этот [Future]
  final Future<void>? downloadGate;

  final requestedUrls = <String>[];
  final downloads = <({String url, String quality})>[];

  FakeVideoRepository({
    this.infoResults = const [],
    this.downloadResults = const [],
    this.progressToReport = const [],
    this.downloadGate,
  });

  @override
  ErrorHandler get errorHandler => const VideoErrorHandler();

  @override
  Future<OperationResult<VideoInfoModel>> getVideoInfo(String url) async {
    requestedUrls.add(url);

    return infoResults[requestedUrls.length - 1];
  }

  @override
  Future<OperationResult<String>> downloadVideo({
    required String url,
    required String quality,
    void Function(DownloadProgressModel progress)? onProgress,
  }) async {
    downloads.add((url: url, quality: quality));
    progressToReport.forEach(onProgress ?? (_) {});
    await downloadGate;

    return downloadResults[downloads.length - 1];
  }
}

class FakeAuthenticationRepository
    implements AuthenticationRepositoryInterface {
  OperationResult<bool> restoreResult;
  OperationResult<bool> signInResult;
  OperationResult<void> signOutResult;

  var signInCalls = 0;

  FakeAuthenticationRepository({
    this.restoreResult = (failure: null, data: false),
    this.signInResult = (failure: null, data: true),
    this.signOutResult = (failure: null, data: null),
  });

  @override
  ErrorHandler get errorHandler => const AuthenticationErrorHandler();

  @override
  Future<OperationResult<bool>> restoreSession() async => restoreResult;

  @override
  Future<OperationResult<bool>> signIn() async {
    signInCalls++;

    return signInResult;
  }

  @override
  Future<OperationResult<void>> signOut() async => signOutResult;
}

const testVideoInfo = VideoInfoModel(
  id: 'kgA8JPY2lIA',
  title: 'Обзор',
  url: 'https://www.youtube.com/watch?v=kgA8JPY2lIA',
  qualities: [
    QualityModel(
      id: '2160',
      kind: QualityKind.video,
      label: '2160p',
      resolution: 2160,
    ),
    QualityModel(
      id: '1080',
      kind: QualityKind.video,
      label: '1080p',
      resolution: 1080,
    ),
    QualityModel(id: QualityModel.audioId, kind: QualityKind.audio, isAac: true),
  ],
);
