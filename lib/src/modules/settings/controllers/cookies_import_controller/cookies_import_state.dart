part of 'cookies_import_controller.dart';

class CookiesImportState extends Equatable {
  /// The file picker is open or the file is being checked
  final bool isImporting;

  /// The last import succeeded: a confirmation is shown
  final bool isImported;

  /// Why the last import failed
  final Failure? failure;

  const CookiesImportState({
    this.isImporting = false,
    this.isImported = false,
    this.failure,
  });

  @override
  List<Object?> get props => [isImporting, isImported, failure];

  CookiesImportState copyWith({
    bool? isImporting,
    bool? isImported,
    Failure? failure,
    bool clearFailure = false,
  }) => CookiesImportState(
    isImporting: isImporting ?? this.isImporting,
    isImported: isImported ?? this.isImported,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}

final class CookiesImportInitialState extends CookiesImportState {
  const CookiesImportInitialState();
}
