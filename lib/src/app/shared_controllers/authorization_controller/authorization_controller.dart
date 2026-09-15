import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../failure/failure.dart';
import '../../logger/app_logger.dart';
import '../../operation_result/operation_result.dart';
import '../../repositories/repositories.dart';

part 'authorization_state.dart';

/// App-wide YouTube account sign-in state
final class AuthorizationController extends Cubit<AuthorizationState> {
  static const _appLogger = AppLogger(where: 'AuthorizationController');

  final AuthenticationRepositoryInterface _authenticationRepository;

  AuthorizationController({required this._authenticationRepository})
    : super(const AuthorizationInitial());

  /// Silent check of the saved session on launch
  Future<void> checkAuthorization() async {
    final result = await _authenticationRepository.restoreSession();

    emit(
      result.isSuccess && result.data == true
          ? const Authorized()
          : const Unauthorized(),
    );
  }

  /// Opens the sign-in window. `true`: signed in
  Future<bool> signIn() async {
    if (state is AuthorizationInProgress) {
      return false;
    }

    final previousState = state;

    emit(const AuthorizationInProgress());

    final result = await _authenticationRepository.signIn();

    if (result.isFailed) {
      final failure = result.failure ?? const OtherFailure();

      _appLogger.logFailure(failure, 'Failed to sign in');

      emit(
        previousState is Authorized
            ? Authorized(failure: failure)
            : Unauthorized(failure: failure),
      );

      return false;
    }

    if (result.data != true) {
      /// The window was closed: everything stays as it was
      emit(previousState is Authorized ? const Authorized() : const Unauthorized());

      return false;
    }

    emit(const Authorized());

    return true;
  }

  Future<void> signOut() async {
    final result = await _authenticationRepository.signOut();

    if (result.isFailed) {
      _appLogger.logFailure(result.failure!, 'Failed to sign out');
    }

    emit(Unauthorized(failure: result.failure));
  }
}
