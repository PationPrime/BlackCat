part of 'authorization_controller.dart';

sealed class AuthorizationState extends Equatable {
  /// Error of the last sign-in or sign-out attempt
  final Failure? failure;

  const AuthorizationState({this.failure});

  @override
  List<Object?> get props => [failure];
}

/// The saved session is still being checked
final class AuthorizationInitial extends AuthorizationState {
  const AuthorizationInitial();
}

/// The sign-in window is open
final class AuthorizationInProgress extends AuthorizationState {
  const AuthorizationInProgress();
}

final class Authorized extends AuthorizationState {
  const Authorized({super.failure});
}

final class Unauthorized extends AuthorizationState {
  const Unauthorized({super.failure});
}

extension AuthorizationStateX on AuthorizationState {
  bool get isChecking => this is AuthorizationInitial;
  bool get isInProgress => this is AuthorizationInProgress;
  bool get isAuthorized => this is Authorized;

  /// Checking or signing in: sign-in buttons are unavailable
  bool get isBusy => isChecking || isInProgress;
}
