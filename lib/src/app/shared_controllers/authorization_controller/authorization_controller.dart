import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../failure/failure.dart';
import '../../logger/app_logger.dart';
import '../../models/models.dart';
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
      switch (result.data) {
        final session? => Authorized(session: session),
        null => const Unauthorized(),
      },
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
            ? Authorized(session: previousState.session, failure: failure)
            : Unauthorized(failure: failure),
      );

      return false;
    }

    if (result.data != true) {
      /// The window was closed: everything stays as it was
      emit(
        previousState is Authorized
            ? Authorized(session: previousState.session)
            : const Unauthorized(),
      );

      return false;
    }

    emit(const Authorized(session: AccountSessionModel.signInWindow()));

    return true;
  }

  /// Picks a cookies.txt and signs in with it. The error is returned to the
  /// caller instead of the state: it belongs to the settings screen.
  /// `null` data: the user closed the picker
  Future<OperationResult<AccountSessionModel?>> importCookies() async {
    if (state.isBusy) {
      return ok(null);
    }

    final result = await _authenticationRepository.importCookies();

    if (result.data case final session?) {
      emit(Authorized(session: session));
    }

    return result;
  }

  Future<void> signOut() async {
    final result = await _authenticationRepository.signOut();

    if (result.isFailed) {
      _appLogger.logFailure(result.failure!, 'Failed to sign out');
    }

    emit(Unauthorized(failure: result.failure));
  }
}
