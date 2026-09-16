import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/operation_result/operation_result.dart';
import 'package:youtube_downloader/src/app/shared_controllers/shared_controllers.dart';

import '../../support/fake_repositories.dart';

void main() {
  test('checkAuthorization: сохранённая сессия подключает аккаунт без окна', () async {
    final controller = AuthorizationController(
      authenticationRepository: FakeAuthenticationRepository(
        restoreResult: (failure: null, data: const AccountSessionModel.signInWindow()),
      ),
    );

    expect(controller.state.isChecking, isTrue);

    await controller.checkAuthorization();

    expect(controller.state, const Authorized());
    expect(controller.state.session?.isImported, isFalse);
  });

  test('checkAuthorization: импортированный cookies.txt помнит свой файл', () async {
    final session = AccountSessionModel.cookiesFile(
      cookiesFilePath: r'C:\Users\user\cookies.txt',
      importedAt: DateTime(2026, 9, 16, 14, 30),
    );
    final controller = AuthorizationController(
      authenticationRepository: FakeAuthenticationRepository(restoreResult: (failure: null, data: session)),
    );

    await controller.checkAuthorization();

    expect(controller.state, Authorized(session: session));
    expect(controller.state.session?.cookiesFilePath, r'C:\Users\user\cookies.txt');
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
        restoreResult: (failure: null, data: const AccountSessionModel.signInWindow()),
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

  test('importCookies: импорт подключает аккаунт, ошибка не попадает в общее состояние', () async {
    final session = AccountSessionModel.cookiesFile(
      cookiesFilePath: r'C:\Users\user\cookies.txt',
      importedAt: DateTime(2026, 9, 16),
    );
    final repository = FakeAuthenticationRepository(importResult: (failure: null, data: session));
    final controller = AuthorizationController(authenticationRepository: repository);

    await controller.checkAuthorization();

    final imported = await controller.importCookies();

    expect(imported.data, session);
    expect(controller.state, Authorized(session: session));

    const failure = AuthenticationFailure(code: 'cookies_format', message: 'не cookies.txt');

    repository.importResult = (failure: failure, data: null);

    final failed = await controller.importCookies();

    expect(failed.failure, failure);
    expect(controller.state, Authorized(session: session));
  });

  test('importCookies: закрытый выбор файла ничего не меняет', () async {
    final controller = AuthorizationController(authenticationRepository: FakeAuthenticationRepository());

    await controller.checkAuthorization();

    final result = await controller.importCookies();

    expect(result.isSuccess, isTrue);
    expect(result.data, isNull);
    expect(controller.state, const Unauthorized());
  });
}
