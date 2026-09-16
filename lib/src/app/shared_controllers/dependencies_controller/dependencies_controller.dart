import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../errors/errors.dart';
import '../../failure/failure.dart';
import '../../logger/app_logger.dart';
import '../../models/models.dart';
import '../../operation_result/operation_result.dart';
import '../../repositories/repositories.dart';
import '../../tools/tools.dart';

part 'dependencies_state.dart';

/// yt-dlp and its JavaScript runtime: whether they are installed and their
/// installation. New videos are downloaded with yt-dlp while both are
/// present, otherwise with the built-in downloader
final class DependenciesController extends Cubit<DependenciesState> {
  static const _appLogger = AppLogger(where: 'DependenciesController');

  final DependenciesRepositoryInterface _dependenciesRepository;

  DownloadCancellation? _installCancellation;

  DependenciesController({required this._dependenciesRepository})
    : super(const DependenciesInitialState());

  void _safeEmit(DependenciesState state) {
    if (isClosed) return;

    emit(state);
  }

  @override
  Future<void> close() async {
    _installCancellation?.cancel();

    await super.close();
  }

  /// Looks the programs up again: they can be installed while the app runs
  Future<void> check() async {
    if (state.status.isBusy) return;

    if (!_dependenciesRepository.isSupported) {
      _safeEmit(state.copyWith(status: DependenciesStatus.unsupported));

      return;
    }

    _safeEmit(
      state.copyWith(status: DependenciesStatus.checking, clearFailure: true),
    );

    final setupResponse = await _dependenciesRepository.getSetup(refresh: true);

    if (setupResponse.isFailed) {
      _logAndEmitFailure(setupResponse.failure, 'Failed to find yt-dlp');

      return;
    }

    final setup = setupResponse.requireData;

    _safeEmit(
      state.copyWith(
        status: setup.isReady
            ? DependenciesStatus.ready
            : DependenciesStatus.missing,
        setup: setup,
      ),
    );
  }

  /// Installs what is missing. `true`: yt-dlp is ready
  Future<bool> install() async {
    if (state.status.isBusy) return false;

    if (state.status.isReady) return true;

    final cancellation = DownloadCancellation();
    _installCancellation = cancellation;

    _safeEmit(
      state.copyWith(
        status: DependenciesStatus.installing,
        installing: state.setup?.missing ?? DependencyKind.values,
        installed: const {},
        clearProgress: true,
        clearFailure: true,
      ),
    );

    final installResponse = await _dependenciesRepository.installMissing(
      cancellation: cancellation,
      onProgress: _onProgress,
    );

    if (_installCancellation == cancellation) {
      _installCancellation = null;
    }

    if (installResponse.isFailed) {
      /// Part of the programs may be installed by now: the next attempt
      /// shows and installs only the rest
      final setupResponse = await _dependenciesRepository.getSetup(
        refresh: true,
      );

      _safeEmit(state.copyWith(setup: setupResponse.data));
      _logAndEmitFailure(installResponse.failure, 'Failed to install yt-dlp');

      return false;
    }

    final setup = installResponse.requireData;

    _safeEmit(
      state.copyWith(
        status: DependenciesStatus.ready,
        setup: setup,
        installed: state.installing.toSet(),
        clearProgress: true,
      ),
    );

    return true;
  }

  /// Stops the installation; the downloaded parts are deleted
  void cancelInstall() {
    _installCancellation?.cancel();
  }

  void _onProgress(DependencyInstallProgressModel progress) {
    if (!state.status.isInstalling) return;

    _safeEmit(
      state.copyWith(
        progress: progress,
        installed: progress.stage.isDone
            ? {...state.installed, progress.kind}
            : null,
      ),
    );
  }

  /// A canceled installation is not an error worth logging
  void _logAndEmitFailure(Failure? failure, String description) {
    final effectiveFailure = failure ?? const OtherFailure();

    if (effectiveFailure.code != const DependencyErrorCodes().canceled) {
      _appLogger.logFailure(effectiveFailure, description);
    }

    _safeEmit(
      state.copyWith(
        status: DependenciesStatus.failed,
        failure: effectiveFailure,
      ),
    );
  }
}
