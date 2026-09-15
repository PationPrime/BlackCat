import '../../data_sources/data_sources.dart';
import '../../errors/errors.dart';
import '../../logger/app_logger.dart';
import '../../operation_result/operation_result.dart';
import '../../tools/tools.dart';
import 'authentication_repository_interface.dart';

/// Вход в YouTube: окно WebView2 с постоянным профилем. «Возврат» входа —
/// последний редирект на youtube.com; к этому моменту Google выставил cookies
/// сессии, и они сохраняются как cookies.txt. Профиль хранит сессию Google,
/// поэтому при следующих запусках вход подхватывается без окна
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

      /// Файла нет или сессия в нём истекла, но профиль окна входа
      /// ещё может хранить аккаунт (например, окно закрыли сразу после входа)
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

      /// Иначе следующий вход (или запуск) молча подхватит сессию Google
      await _localDataSource.deleteSignInProfile();

      return ok(null);
    } catch (error, stackTrace) {
      return fail(errorHandler.handleError(error, stackTrace: stackTrace));
    }
  }
}
