part of 'settings_controller.dart';

class SettingsState extends Equatable {
  final bool isLoading;

  /// `null` until the settings are loaded
  final DownloadDirectoryModel? downloadDirectory;

  /// Interface language: the app applies it as soon as it changes
  final AppLanguageModel language;

  /// Version of the running build. `null` until it is read, or when the
  /// build does not tell it
  final AppVersionModel? appVersion;
  final Failure? failure;

  const SettingsState({
    this.isLoading = false,
    this.downloadDirectory,
    this.language = AppLanguageModel.fallback,
    this.appVersion,
    this.failure,
  });

  @override
  List<Object?> get props => [
    isLoading,
    downloadDirectory,
    language,
    appVersion,
    failure,
  ];

  SettingsState copyWith({
    bool? isLoading,
    DownloadDirectoryModel? downloadDirectory,
    AppLanguageModel? language,
    AppVersionModel? appVersion,
    Failure? failure,
    bool clearFailure = false,
  }) => SettingsState(
    isLoading: isLoading ?? this.isLoading,
    downloadDirectory: downloadDirectory ?? this.downloadDirectory,
    language: language ?? this.language,
    appVersion: appVersion ?? this.appVersion,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}

final class SettingsInitialState extends SettingsState {
  const SettingsInitialState({super.language});
}
