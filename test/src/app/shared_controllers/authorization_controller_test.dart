import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/shared_controllers/shared_controllers.dart';

import '../../support/fake_repositories.dart';

void main() {
  test('checkAuthorization: сохранённая сессия подключает аккаунт без окна', () async {
    final controller = AuthorizationController(
      authenticationRepository: FakeAuthenticationRepository(restoreResult: (failure: null, data: true)),
    );

    expect(controller.state.isChecking, isTrue);

    await controller.checkAuthorization();

    expect(controller.state, const Authorized());
  });

  test('checkAuthorization: без сессии — не подключён', () async {
    final controller = AuthorizationController(authenticationRepository: FakeAuthenticationRepository());

    await controller.checkAuthorization();

    expect(controller.state, const Unauthorized());
  });

  test('signIn: успешный вход', () async {
    final controller = AuthorizationController(authenticationRepository: FakeAuthenticationRepository());
    final states = <AuthorizationState>[];
    final subscription = controller.stream.listen(states.add);

    expect(await controller.signIn(), isTrue);

    /// Stream events are delivered asynchronously
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    expect(states, [const AuthorizationInProgress(), const Authorized()]);
  });

  test('signIn: закрытое окно возвращает прежнее состояние', () async {
    final controller = AuthorizationController(
      authenticationRepository: FakeAuthenticationRepository(
        restoreResult: (failure: null, data: true),
        signInResult: (failure: null, data: false),
      ),
    );

    await controller.checkAuthorization();

    expect(await controller.signIn(), isFalse);
    expect(controller.state, const Authorized());
  });

  test('signIn: ошибка попадает в состояние', () async {
    const failure = AuthenticationFailure(code: 'session_not_issued', message: 'нет cookies');
    final controller = AuthorizationController(
      authenticationRepository: FakeAuthenticationRepository(signInResult: (failure: failure, data: null)),
    );

    expect(await controller.signIn(), isFalse);
    expect(controller.state, const Unauthorized(failure: failure));
  });
}
