part of 'settings_controller.dart';

class SettingsState extends Equatable {
  final bool isLoading;

  /// `null` until the settings are loaded
  final DownloadDirectoryModel? downloadDirectory;

  /// Interface language: the app applies it as soon as it changes
  final AppLanguageModel language;
  final Failure? failure;

  const SettingsState({
    this.isLoading = false,
    this.downloadDirectory,
    this.language = AppLanguageModel.fallback,
    this.failure,
  });

  @override
  List<Object?> get props => [isLoading, downloadDirectory, language, failure];

  SettingsState copyWith({
    bool? isLoading,
    DownloadDirectoryModel? downloadDirectory,
    AppLanguageModel? language,
    Failure? failure,
    bool clearFailure = false,
  }) => SettingsState(
    isLoading: isLoading ?? this.isLoading,
    downloadDirectory: downloadDirectory ?? this.downloadDirectory,
    language: language ?? this.language,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}

final class SettingsInitialState extends SettingsState {
  const SettingsInitialState({super.language});
}
