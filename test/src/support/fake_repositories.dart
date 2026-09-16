import 'dart:async';

import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/failure/failure.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/operation_result/operation_result.dart';
import 'package:youtube_downloader/src/app/repositories/repositories.dart';
import 'package:youtube_downloader/src/app/tools/tools.dart';

/// A download call controlled by the test: reports streams and progress,
/// completes with success or an error. Stopping via `cancellation`
/// completes it with a cancel error, like the real repository
class FakeDownloadCall {
  final String taskId;
  final String url;
  final String quality;
  final List<DownloadStreamModel> streams;
  final String? destinationDirectory;
  final DownloadCancellation? cancellation;
  final void Function(List<DownloadStreamModel> streams)? onStreamsSelected;
  final void Function(DownloadProgressModel progress)? onProgress;

  final _completer = Completer<OperationResult<DownloadedFileModel>>();

  FakeDownloadCall({
    required this.taskId,
    required this.url,
    required this.quality,
    required this.streams,
    this.destinationDirectory,
    this.cancellation,
    this.onStreamsSelected,
    this.onProgress,
  }) {
    cancellation?.whenCancelled.then((_) {
      if (!_completer.isCompleted) {
        _completer.complete(
          fail(VideoFailure(code: const VideoErrorCodes().canceled)),
        );
      }
    });
  }

  Future<OperationResult<DownloadedFileModel>> get result => _completer.future;

  bool get isCancelled => cancellation?.isCancelled ?? false;

  void selectStreams(List<DownloadStreamModel> streams) =>
      onStreamsSelected?.call(streams);

  void reportProgress(DownloadProgressModel progress) =>
      onProgress?.call(progress);

  void succeed(String filePath, {int sizeBytes = 1024}) => _completer.complete(
    ok(DownloadedFileModel(path: filePath, sizeBytes: sizeBytes)),
  );

  void failWith(Failure failure) => _completer.complete(fail(failure));
}

class FakeVideoRepository implements VideoRepositoryInterface {
  final List<OperationResult<VideoInfoModel>> infoResults;

  final requestedUrls = <String>[];
  final downloads = <FakeDownloadCall>[];

  FakeVideoRepository({this.infoResults = const []});

  @override
  ErrorHandler get errorHandler => const VideoErrorHandler();

  @override
  Future<OperationResult<VideoInfoModel>> getVideoInfo(String url) async {
    requestedUrls.add(url);

    return infoResults[requestedUrls.length - 1];
  }

  @override
  Future<OperationResult<DownloadedFileModel>> downloadVideo({
    required String taskId,
    required String url,
    required String quality,
    List<DownloadStreamModel> streams = const [],
    String? destinationDirectory,
    DownloadCancellation? cancellation,
    void Function(List<DownloadStreamModel> streams)? onStreamsSelected,
    void Function(DownloadProgressModel progress)? onProgress,
  }) {
    final call = FakeDownloadCall(
      taskId: taskId,
      url: url,
      quality: quality,
      streams: streams,
      destinationDirectory: destinationDirectory,
      cancellation: cancellation,
      onStreamsSelected: onStreamsSelected,
      onProgress: onProgress,
    );

    downloads.add(call);

    return call.result;
  }
}

/// yt-dlp stand-in: the same controllable downloads
class FakeYtDlpVideoRepository extends FakeVideoRepository implements YtDlpVideoRepositoryInterface {
  FakeYtDlpVideoRepository({super.infoResults});
}

const testYtDlp = DependencyToolModel(name: 'yt-dlp', executable: 'yt-dlp', version: '2026.08.19');
const testDeno = DependencyToolModel(name: 'deno', executable: r'C:\Tools\deno.exe', version: 'deno 2.9.6', isBundled: true);
const testReadySetup = YtDlpSetupModel(ytDlp: testYtDlp, jsRuntime: testDeno);

/// Installation controlled by the test: reports steps and completes
/// with success or an error. Stopping completes it with a cancel error
class FakeInstallCall {
  final void Function(DependencyInstallProgressModel progress) onProgress;
  final DownloadCancellation? cancellation;

  final _completer = Completer<OperationResult<YtDlpSetupModel>>();

  FakeInstallCall({required this.onProgress, this.cancellation}) {
    cancellation?.whenCancelled.then((_) {
      if (!_completer.isCompleted) {
        _completer.complete(fail(DependencyFailure(code: const DependencyErrorCodes().canceled, message: 'Установка отменена.')));
      }
    });
  }

  Future<OperationResult<YtDlpSetupModel>> get result => _completer.future;

  void report(DependencyInstallProgressModel progress) => onProgress(progress);

  void succeed([YtDlpSetupModel setup = testReadySetup]) => _completer.complete(ok(setup));

  void failWith(Failure failure) => _completer.complete(fail(failure));
}

class FakeDependenciesRepository implements DependenciesRepositoryInterface {
  @override
  bool isSupported;

  /// Answers of the lookups in turn; the last one repeats
  List<OperationResult<YtDlpSetupModel>> setupResults;
  final installs = <FakeInstallCall>[];
  var setupCalls = 0;

  FakeDependenciesRepository({
    this.isSupported = true,
    this.setupResults = const [(failure: null, data: testReadySetup)],
  });

  @override
  ErrorHandler get errorHandler => const DependencyErrorHandler();

  @override
  Future<OperationResult<YtDlpSetupModel>> getSetup({bool refresh = false}) async =>
      setupResults[(setupCalls++).clamp(0, setupResults.length - 1)];

  @override
  Future<OperationResult<YtDlpSetupModel>> installMissing({
    required void Function(DependencyInstallProgressModel progress) onProgress,
    DownloadCancellation? cancellation,
  }) {
    final call = FakeInstallCall(onProgress: onProgress, cancellation: cancellation);

    installs.add(call);

    return call.result;
  }
}

/// In-memory queue: what was saved and what was removed
class FakeDownloadQueueRepository implements DownloadQueueRepositoryInterface {
  OperationResult<List<DownloadTaskModel>> restoreResult;

  /// The last saved state of each download
  final saved = <String, DownloadTaskModel>{};
  final removedTaskIds = <String>[];
  final progressUpdates = <({String taskId, int downloadedBytes})>[];

  /// Thumbnail copy path returned for every download; `null`: the video has no thumbnail
  OperationResult<String?> thumbnailResult = (failure: null, data: r'C:\Thumbnails\thumb.jpg');
  final thumbnailTaskIds = <String>[];

  FakeDownloadQueueRepository({
    this.restoreResult = (failure: null, data: const []),
  });

  @override
  ErrorHandler get errorHandler => const DownloadQueueErrorHandler();

  @override
  Future<OperationResult<List<DownloadTaskModel>>> restoreTasks() async =>
      restoreResult;

  @override
  Future<OperationResult<void>> saveTasks(List<DownloadTaskModel> tasks) async {
    for (final task in tasks) {
      saved[task.id] = task;
    }

    return ok(null);
  }

  @override
  Future<OperationResult<void>> updateProgress({
    required String taskId,
    required int downloadedBytes,
    int? totalBytes,
  }) async {
    progressUpdates.add((taskId: taskId, downloadedBytes: downloadedBytes));

    return ok(null);
  }

  @override
  Future<OperationResult<String?>> saveThumbnail(DownloadTaskModel task) async {
    thumbnailTaskIds.add(task.id);

    return thumbnailResult;
  }

  @override
  Future<OperationResult<void>> removeTasks(List<String> taskIds) async {
    removedTaskIds.addAll(taskIds);
    taskIds.forEach(saved.remove);

    return ok(null);
  }
}

class FakeSettingsRepository implements SettingsRepositoryInterface {
  OperationResult<DownloadDirectoryModel> directoryResult;
  OperationResult<DownloadDirectoryModel?> pickResult;
  OperationResult<DownloadDirectoryModel> resetResult;
  OperationResult<AppLanguageModel> languageResult;
  OperationResult<AppLanguageModel>? setLanguageResult;

  final pickInitialDirectories = <String?>[];
  final savedLanguages = <AppLanguageModel>[];

  FakeSettingsRepository({
    this.directoryResult = (
      failure: null,
      data: const DownloadDirectoryModel(
        path: r'C:\Users\user\Downloads',
        isDefault: true,
      ),
    ),
    this.pickResult = (failure: null, data: null),
    this.resetResult = (
      failure: null,
      data: const DownloadDirectoryModel(
        path: r'C:\Users\user\Downloads',
        isDefault: true,
      ),
    ),
    this.languageResult = (failure: null, data: AppLanguageModel.russian),
    this.setLanguageResult,
  });

  @override
  ErrorHandler get errorHandler => const SettingsErrorHandler();

  @override
  Future<OperationResult<DownloadDirectoryModel>>
  getDownloadDirectory() async => directoryResult;

  @override
  Future<OperationResult<DownloadDirectoryModel?>> pickDownloadDirectory({
    String? initialDirectory,
  }) async {
    pickInitialDirectories.add(initialDirectory);

    return pickResult;
  }

  @override
  Future<OperationResult<DownloadDirectoryModel>>
  resetDownloadDirectory() async => resetResult;

  @override
  Future<OperationResult<AppLanguageModel>> getLanguage() async => languageResult;

  @override
  Future<OperationResult<AppLanguageModel>> setLanguage(AppLanguageModel language) async {
    savedLanguages.add(language);

    return setLanguageResult ?? (failure: null, data: language);
  }
}

class FakeAuthenticationRepository
    implements AuthenticationRepositoryInterface {
  OperationResult<AccountSessionModel?> restoreResult;
  OperationResult<bool> signInResult;
  OperationResult<AccountSessionModel?> importResult;
  OperationResult<void> signOutResult;

  var signInCalls = 0;
  var importCalls = 0;
  var signOutCalls = 0;

  FakeAuthenticationRepository({
    this.restoreResult = (failure: null, data: null),
    this.signInResult = (failure: null, data: true),
    this.importResult = (failure: null, data: null),
    this.signOutResult = (failure: null, data: null),
  });

  @override
  ErrorHandler get errorHandler => const AuthenticationErrorHandler();

  @override
  Future<OperationResult<AccountSessionModel?>> restoreSession() async => restoreResult;

  @override
  Future<OperationResult<bool>> signIn() async {
    signInCalls++;

    return signInResult;
  }

  @override
  Future<OperationResult<AccountSessionModel?>> importCookies() async {
    importCalls++;

    return importResult;
  }

  @override
  Future<OperationResult<void>> signOut() async {
    signOutCalls++;

    return signOutResult;
  }
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
