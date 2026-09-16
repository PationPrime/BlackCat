import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:path/path.dart' as p;

import '../../data_sources/data_sources.dart';
import '../../errors/errors.dart';
import '../../localization/lang/locale_keys.g.dart';
import '../../logger/app_logger.dart';
import '../../models/models.dart';
import '../../operation_result/operation_result.dart';
import '../../services/services.dart';
import '../../tools/tools.dart';
import 'authentication_repository_interface.dart';

/// YouTube sign-in: a WebView2 window with a persistent profile. The sign-in
/// "callback" is the last redirect to youtube.com; by then Google has set the
/// session cookies, and they are saved as cookies.txt. The profile keeps the Google
/// session, so on later launches the sign-in is picked up without a window.
///
/// A cookies.txt exported from a browser signs in the same way: its YouTube
/// and Google cookies replace the saved ones
final class AuthenticationRepository
    implements AuthenticationRepositoryInterface {
  static const _appLogger = AppLogger(where: 'AuthenticationRepository');

  static const _cookiesExtensions = ['txt'];
  static const _cookiesMimeTypes = ['text/plain'];

  final LocalAuthenticationDataSource _localDataSource;
  final WebAuthenticationDataSource _webDataSource;
  final FileSelectorService _fileSelectorService;

  const AuthenticationRepository({
    required this._localDataSource,
    required this._webDataSource,
    required this._fileSelectorService,
  });

  @override
  ErrorHandler<AuthenticationErrorCodes> get errorHandler =>
      const AuthenticationErrorHandler();

  @override
  Future<OperationResult<AccountSessionModel?>> restoreSession() async {
    try {
      final savedCookies = await _localDataSource.readCookies();

      if (savedCookies != null &&
          NetscapeCookies.hasYouTubeSession(savedCookies)) {
        return ok(
          await _localDataSource.readCookiesSource() ??
              const AccountSessionModel.signInWindow(),
        );
      }

      /// The file is missing or its session has expired, but the sign-in window profile
      /// may still hold the account (e.g. the window was closed right after signing in)
      if (!await _localDataSource.signInProfileExists()) {
        return ok(null);
      }

      final profileCookies = (await _webDataSource.readProfileCookies())
          .where(NetscapeCookies.isYouTubeOrGoogle)
          .toList();

      if (!NetscapeCookies.hasYouTubeSession(profileCookies)) {
        return ok(null);
      }

      await _saveSession(
        profileCookies,
        const AccountSessionModel.signInWindow(),
      );

      return ok(const AccountSessionModel.signInWindow());
    } catch (error, stackTrace) {
      final failure = errorHandler.handleError(error, stackTrace: stackTrace);

      _appLogger.logFailure(failure, 'Failed to restore YouTube session');

      return fail(failure);
    }
  }

  @override
  Future<OperationResult<bool>> signIn() async {
    try {
      final cookies = await _webDataSource.signIn();

      if (cookies == null) {
        return ok(false);
      }

      final accountCookies = cookies
          .where(NetscapeCookies.isYouTubeOrGoogle)
          .toList();

      if (!NetscapeCookies.hasYouTubeSession(accountCookies)) {
        throw AuthenticationException(
          const AuthenticationErrorCodes().sessionNotIssued,
        );
      }

      await _saveSession(
        accountCookies,
        const AccountSessionModel.signInWindow(),
      );

      return ok(true);
    } catch (error, stackTrace) {
      return fail(errorHandler.handleError(error, stackTrace: stackTrace));
    }
  }

  @override
  Future<OperationResult<AccountSessionModel?>> importCookies() async {
    const codes = AuthenticationErrorCodes();

    try {
      final String? path;

      try {
        final previous = await _localDataSource.readCookiesSource();

        path = await _fileSelectorService.pickFile(
          typeLabel: LocaleKeys.app_settings_cookies_picker_label.tr(),
          extensions: _cookiesExtensions,
          mimeTypes: _cookiesMimeTypes,
          initialDirectory: switch (previous?.cookiesFilePath) {
            final previousPath? => p.dirname(previousPath),
            null => null,
          },
          confirmButtonText: LocaleKeys.app_settings_cookies_picker_confirm
              .tr(),
        );
      } catch (error) {
        throw AuthenticationException(codes.cookiesPicker, cause: error);
      }

      if (path == null) {
        return ok(null);
      }

      final Uint8List bytes;

      try {
        bytes = await _localDataSource.readImportFile(path);
      } on FileSystemException catch (error) {
        throw AuthenticationException(
          codes.cookiesRead,
          cause: error.osError?.message ?? error.message,
        );
      }

      final cookies = CookiesFileParser.parse(
        bytes,
        fileName: p.basename(path),
      );
      final session = AccountSessionModel.cookiesFile(
        cookiesFilePath: path,
        importedAt: DateTime.now(),
      );

      try {
        await _saveSession(cookies, session);
      } on FileSystemException catch (error) {
        throw AuthenticationException(
          codes.cookiesSave,
          cause: error.osError?.message ?? error.message,
        );
      }

      return ok(session);
    } catch (error, stackTrace) {
      final failure = errorHandler.handleError(error, stackTrace: stackTrace);

      _appLogger.logFailure(failure, 'Failed to import cookies');

      return fail(failure);
    }
  }

  @override
  Future<OperationResult<void>> signOut() async {
    try {
      await _localDataSource.deleteCookies();

      /// Otherwise the next sign-in (or launch) silently picks up the Google session
      await _localDataSource.deleteSignInProfile();

      return ok(null);
    } catch (error, stackTrace) {
      return fail(errorHandler.handleError(error, stackTrace: stackTrace));
    }
  }

  /// The note of the source goes first: a stale note must not outlive
  /// the cookies it describes
  Future<void> _saveSession(
    List<BrowserCookieModel> cookies,
    AccountSessionModel session,
  ) async {
    await _localDataSource.writeCookiesSource(null);
    await _localDataSource.writeCookies(cookies);
    await _localDataSource.writeCookiesSource(session);
  }
}
