import '../../data_sources/data_sources.dart';
import '../../errors/errors.dart';
import '../../logger/app_logger.dart';
import '../../operation_result/operation_result.dart';
import '../../tools/tools.dart';
import 'authentication_repository_interface.dart';

/// YouTube sign-in: a WebView2 window with a persistent profile. The sign-in
/// "callback" is the last redirect to youtube.com; by then Google has set the
/// session cookies, and they are saved as cookies.txt. The profile keeps the Google
/// session, so on later launches the sign-in is picked up without a window
final class AuthenticationRepository
    implements AuthenticationRepositoryInterface {
  static const _appLogger = AppLogger(where: 'AuthenticationRepository');

  final LocalAuthenticationDataSource _localDataSource;
  final WebAuthenticationDataSource _webDataSource;

  const AuthenticationRepository({
    required this._localDataSource,
    required this._webDataSource,
  });

  @override
  ErrorHandler<AuthenticationErrorCodes> get errorHandler =>
      const AuthenticationErrorHandler();

  @override
  Future<OperationResult<bool>> restoreSession() async {
    try {
      final savedCookies = await _localDataSource.readCookies();

      if (savedCookies != null &&
          NetscapeCookies.hasYouTubeSession(savedCookies)) {
        return ok(true);
      }

      /// The file is missing or its session has expired, but the sign-in window profile
      /// may still hold the account (e.g. the window was closed right after signing in)
      if (!await _localDataSource.signInProfileExists()) {
        return ok(false);
      }

      final profileCookies = (await _webDataSource.readProfileCookies())
          .where(NetscapeCookies.isYouTubeOrGoogle)
          .toList();

      if (!NetscapeCookies.hasYouTubeSession(profileCookies)) {
        return ok(false);
      }

      await _localDataSource.writeCookies(profileCookies);

      return ok(true);
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

      await _localDataSource.writeCookies(accountCookies);

      return ok(true);
    } catch (error, stackTrace) {
      return fail(errorHandler.handleError(error, stackTrace: stackTrace));
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
}
