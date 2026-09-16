import '../../models/models.dart';
import '../../operation_result/operation_result.dart';
import '../base_repository_interface.dart';

abstract interface class AuthenticationRepositoryInterface
    implements BaseRepositoryInterface {
  /// Restores the session on launch without showing windows.
  /// `null`: the account is not connected
  Future<OperationResult<AccountSessionModel?>> restoreSession();

  /// Sign-in through the flutter_web_auth_2 window.
  /// `true`: signed in, `false`: the user closed the window
  Future<OperationResult<bool>> signIn();

  /// Asks for a cookies.txt, checks it and signs in with its cookies,
  /// replacing the current sign-in. `null`: the user closed the picker
  Future<OperationResult<AccountSessionModel?>> importCookies();

  /// Deletes cookies and the Google session from the sign-in window profile
  Future<OperationResult<void>> signOut();
}
