import '../../operation_result/operation_result.dart';
import '../base_repository_interface.dart';

abstract interface class AuthenticationRepositoryInterface
    implements BaseRepositoryInterface {
  /// Восстанавливает сессию при запуске, не показывая окон.
  /// `true` — аккаунт подключён
  Future<OperationResult<bool>> restoreSession();

  /// Вход через окно flutter_web_auth_2.
  /// `true` — вход выполнен, `false` — пользователь закрыл окно
  Future<OperationResult<bool>> signIn();

  /// Удаляет cookies и сессию Google из профиля окна входа
  Future<OperationResult<void>> signOut();
}
