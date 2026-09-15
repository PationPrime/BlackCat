import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/shared_controllers/shared_controllers.dart';
import 'package:youtube_downloader/src/modules/downloader/controllers/controllers.dart';

import '../../support/fake_repositories.dart';

const _url = 'https://youtu.be/kgA8JPY2lIA';

const _signInFailure = VideoFailure(code: 'unplayable', message: 'Войдите в аккаунт', needsSignIn: true);

AddVideoController _controller(
  FakeVideoRepository videoRepository, {
  FakeAuthenticationRepository? authenticationRepository,
}) => AddVideoController(
  videoRepository: videoRepository,
  authorizationController: AuthorizationController(
    authenticationRepository: authenticationRepository ?? FakeAuthenticationRepository(),
  ),
);

void main() {
  test('fetchVideoInfo: информация и качество по умолчанию', () async {
    final repository = FakeVideoRepository(infoResults: [(failure: null, data: testVideoInfo)]);
    final controller = _controller(repository);

    await controller.fetchVideoInfo(_url);

    expect(repository.requestedUrls, [_url]);
    expect(controller.state.videoInfo, testVideoInfo);
    expect(controller.state.selectedQualityId, '1080');
    expect(controller.state.selectedQuality?.label, '1080p');
    expect(controller.state.canAdd, isTrue);
    expect(controller.state.isInfoLoading, isFalse);
  });

  test('fetchVideoInfo: пустая ссылка не ищется', () async {
    final repository = FakeVideoRepository();
    final controller = _controller(repository);

    await controller.fetchVideoInfo('   ');

    expect(repository.requestedUrls, isEmpty);
    expect(controller.state.canAdd, isFalse);
  });

  test('fetchVideoInfo: ошибка показывается и сбрасывается при новом поиске', () async {
    final repository = FakeVideoRepository(
      infoResults: [(failure: _signInFailure, data: null), (failure: null, data: testVideoInfo)],
    );
    final controller = _controller(repository);

    await controller.fetchVideoInfo(_url);

    expect(controller.state.failure, _signInFailure);
    expect(controller.state.videoInfo, isNull);

    await controller.fetchVideoInfo(_url);

    expect(controller.state.failure, isNull);
    expect(controller.state.videoInfo, testVideoInfo);
  });

  test('selectQuality меняет выбранное качество', () async {
    final repository = FakeVideoRepository(infoResults: [(failure: null, data: testVideoInfo)]);
    final controller = _controller(repository);

    await controller.fetchVideoInfo(_url);
    controller.selectQuality(QualityModel.audioId);

    expect(controller.state.selectedQuality?.kind, QualityKind.audio);
  });

  test('signInAndRetry: после входа повторяет поиск', () async {
    final repository = FakeVideoRepository(
      infoResults: [(failure: _signInFailure, data: null), (failure: null, data: testVideoInfo)],
    );
    final authenticationRepository = FakeAuthenticationRepository();
    final controller = _controller(repository, authenticationRepository: authenticationRepository);

    await controller.fetchVideoInfo(_url);
    await controller.signInAndRetry();

    expect(authenticationRepository.signInCalls, 1);
    expect(repository.requestedUrls, [_url, _url]);
    expect(controller.state.videoInfo, testVideoInfo);
  });

  test('signInAndRetry: закрытое окно входа ничего не повторяет', () async {
    final repository = FakeVideoRepository(infoResults: [(failure: _signInFailure, data: null)]);
    final controller = _controller(
      repository,
      authenticationRepository: FakeAuthenticationRepository(signInResult: (failure: null, data: false)),
    );

    await controller.fetchVideoInfo(_url);
    await controller.signInAndRetry();

    expect(repository.requestedUrls, [_url]);
    expect(controller.state.failure, _signInFailure);
  });
}
