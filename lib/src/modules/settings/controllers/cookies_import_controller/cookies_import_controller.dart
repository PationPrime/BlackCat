import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:youtube_downloader/src/app/failure/failure.dart';
import 'package:youtube_downloader/src/app/logger/app_logger.dart';
import 'package:youtube_downloader/src/app/operation_result/operation_result.dart';
import 'package:youtube_downloader/src/app/shared_controllers/shared_controllers.dart';

part 'cookies_import_state.dart';

/// cookies.txt import on the settings screen. The account itself lives in
/// [AuthorizationController]; this controller keeps only the import result
class CookiesImportController extends Cubit<CookiesImportState> {
  static const _appLogger = AppLogger(where: 'CookiesImportController');

  final AuthorizationController _authorizationController;

  CookiesImportController({required this._authorizationController})
    : super(const CookiesImportInitialState());

  void _safeEmit(CookiesImportState state) {
    if (isClosed) return;

    emit(state);
  }

  /// Asks for a cookies.txt and signs in with it
  Future<void> importCookies() async {
    if (state.isImporting) return;

    _safeEmit(
      state.copyWith(isImporting: true, isImported: false, clearFailure: true),
    );

    final importResponse = await _authorizationController.importCookies();

    if (importResponse.isFailed) {
      final failure = importResponse.failure ?? const OtherFailure();

      _appLogger.logFailure(failure, 'Failed to import cookies');

      _safeEmit(state.copyWith(isImporting: false, failure: failure));

      return;
    }

    _safeEmit(
      state.copyWith(
        isImporting: false,

        /// The picker was closed: nothing changed
        isImported: importResponse.data != null,
      ),
    );
  }

  /// Deletes the imported cookies: the app signs out of YouTube
  Future<void> removeCookies() async {
    _safeEmit(state.copyWith(isImported: false, clearFailure: true));

    await _authorizationController.signOut();
  }

  /// An error of the screen to show in the cookies card
  void showFailure(Failure failure) {
    _safeEmit(state.copyWith(isImported: false, failure: failure));
  }

  void dismissFailure() {
    _safeEmit(state.copyWith(clearFailure: true));
  }
}
