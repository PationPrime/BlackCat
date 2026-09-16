part of 'dependencies_controller.dart';

enum DependenciesStatus {
  /// Not checked yet
  unknown,
  checking,

  /// yt-dlp and a JavaScript runtime are installed
  ready,

  /// Something is not installed: the app offers to install it
  missing,
  installing,

  /// The check or installation failed
  failed,

  /// yt-dlp does not run on this platform
  unsupported;

  bool get isReady => this == ready;
  bool get isMissing => this == missing;
  bool get isInstalling => this == installing;
  bool get isFailed => this == failed;
  bool get isBusy => this == checking || this == installing;

  /// The built-in downloader is used and installing may help
  bool get canInstall => this == missing || this == failed;
}

class DependenciesState extends Equatable {
  final DependenciesStatus status;

  /// What was found by the last check or installation
  final YtDlpSetupModel? setup;

  /// Programs the current (or last) installation deals with
  final List<DependencyKind> installing;

  /// Programs the current (or last) installation has finished
  final Set<DependencyKind> installed;

  /// Step of the running installation
  final DependencyInstallProgressModel? progress;
  final Failure? failure;

  const DependenciesState({
    this.status = DependenciesStatus.unknown,
    this.setup,
    this.installing = const [],
    this.installed = const {},
    this.progress,
    this.failure,
  });

  /// Engine for new videos: yt-dlp once it is ready
  DownloadEngineModel get preferredEngine =>
      status.isReady ? DownloadEngineModel.ytDlp : DownloadEngineModel.builtIn;

  bool get isCanceled => failure?.code == const DependencyErrorCodes().canceled;

  @override
  List<Object?> get props => [
    status,
    setup,
    installing,
    installed,
    progress,
    failure,
  ];

  DependenciesState copyWith({
    DependenciesStatus? status,
    YtDlpSetupModel? setup,
    List<DependencyKind>? installing,
    Set<DependencyKind>? installed,
    DependencyInstallProgressModel? progress,
    Failure? failure,
    bool clearProgress = false,
    bool clearFailure = false,
  }) => DependenciesState(
    status: status ?? this.status,
    setup: setup ?? this.setup,
    installing: installing ?? this.installing,
    installed: installed ?? this.installed,
    progress: clearProgress ? null : progress ?? this.progress,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}

final class DependenciesInitialState extends DependenciesState {
  const DependenciesInitialState();
}
