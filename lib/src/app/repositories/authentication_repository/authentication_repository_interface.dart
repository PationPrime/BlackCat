import '../../operation_result/operation_result.dart';
import '../base_repository_interface.dart';

abstract interface class AuthenticationRepositoryInterface
    implements BaseRepositoryInterface {
  /// Restores the session on launch without showing windows.
  /// `true`: the account is connected
  Future<OperationResult<bool>> restoreSession();

  /// Sign-in through the flutter_web_auth_2 window.
  /// `true`: signed in, `false`: the user closed the window
  Future<OperationResult<bool>> signIn();

  /// Deletes cookies and the Google session from the sign-in window profile
  Future<OperationResult<void>> signOut();
}
