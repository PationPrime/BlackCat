part of 'authorization_controller.dart';

sealed class AuthorizationState extends Equatable {
  /// Ошибка последней попытки входа или выхода
  final Failure? failure;

  const AuthorizationState({this.failure});

  @override
  List<Object?> get props => [failure];
}

/// Сохранённая сессия ещё проверяется
final class AuthorizationInitial extends AuthorizationState {
  const AuthorizationInitial();
}

/// Открыто окно входа
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

  /// Идёт проверка или вход: кнопки входа недоступны
  bool get isBusy => isChecking || isInProgress;
}
