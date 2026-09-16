import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/shared_controllers/shared_controllers.dart';
import 'package:youtube_downloader/src/modules/home/controllers/controllers.dart';

import '../../support/fake_repositories.dart';

const _url = 'https://youtu.be/kgA8JPY2lIA';

const _signInFailure = VideoFailure(code: 'unplayable', message: 'Войдите в аккаунт', needsSignIn: true);

AccountSessionModel _importedSession(int day) =>
    AccountSessionModel.cookiesFile(cookiesFilePath: r'C:\cookies.txt', importedAt: DateTime(2026, 9, day));

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

AddVideoController _controller(
  FakeVideoRepository videoRepository, {
  FakeAuthenticationRepository? authenticationRepository,
  FakeYtDlpVideoRepository? ytDlpVideoRepository,
}) => AddVideoController(
  videoRepository: videoRepository,
  ytDlpVideoRepository: ytDlpVideoRepository ?? FakeYtDlpVideoRepository(),
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

  test('fetchVideoInfo через yt-dlp: поиск и повтор после входа идут через yt-dlp', () async {
    final builtIn = FakeVideoRepository();
    final ytDlp = FakeYtDlpVideoRepository(
      infoResults: [(failure: _signInFailure, data: null), (failure: null, data: testVideoInfo)],
    );
    final controller = _controller(builtIn, ytDlpVideoRepository: ytDlp);

    await controller.fetchVideoInfo(_url, engine: DownloadEngineModel.ytDlp);

    expect(controller.state.engine, DownloadEngineModel.ytDlp);

    await controller.signInAndRetry();

    expect(builtIn.requestedUrls, isEmpty);
    expect(ytDlp.requestedUrls, [_url, _url]);
    expect(controller.state.videoInfo, testVideoInfo);
  });

  test('yt-dlp сломался при поиске: ищет встроенный загрузчик, видео качается им', () async {
    final builtIn = FakeVideoRepository(infoResults: [(failure: null, data: testVideoInfo)]);
    final ytDlp = FakeYtDlpVideoRepository(
      infoResults: [(failure: const VideoFailure(code: 'ytdlp_failed', message: 'yt-dlp упал'), data: null)],
    );
    final controller = _controller(builtIn, ytDlpVideoRepository: ytDlp);

    await controller.fetchVideoInfo(_url, engine: DownloadEngineModel.ytDlp);

    expect(ytDlp.requestedUrls, [_url]);
    expect(builtIn.requestedUrls, [_url]);
    expect(controller.state.failure, isNull);
    expect(controller.state.videoInfo, testVideoInfo);
    expect(controller.state.requestedEngine, DownloadEngineModel.ytDlp);
    expect(controller.state.engine, DownloadEngineModel.builtIn);
  });

  test('ошибка видео от yt-dlp показывается без повторного поиска встроенным загрузчиком', () async {
    final builtIn = FakeVideoRepository();
    final ytDlp = FakeYtDlpVideoRepository(infoResults: [(failure: _signInFailure, data: null)]);
    final controller = _controller(builtIn, ytDlpVideoRepository: ytDlp);

    await controller.fetchVideoInfo(_url, engine: DownloadEngineModel.ytDlp);

    expect(builtIn.requestedUrls, isEmpty);
    expect(controller.state.failure, _signInFailure);
    expect(controller.state.engine, DownloadEngineModel.ytDlp);
  });

  test('retry повторяет поиск тем же способом, что и в первый раз', () async {
    final builtIn = FakeVideoRepository(infoResults: [(failure: null, data: testVideoInfo)]);
    final ytDlp = FakeYtDlpVideoRepository(
      infoResults: [
        (failure: const VideoFailure(code: 'ytdlp_not_found', message: 'нет yt-dlp'), data: null),
        (failure: null, data: testVideoInfo),
      ],
    );
    final controller = _controller(builtIn, ytDlpVideoRepository: ytDlp);

    await controller.fetchVideoInfo(_url, engine: DownloadEngineModel.ytDlp);
    await controller.retry();

    expect(ytDlp.requestedUrls, [_url, _url]);
    expect(builtIn.requestedUrls, [_url]);
    expect(controller.state.engine, DownloadEngineModel.ytDlp);
  });

  test('импортированные cookies повторяют поиск, которому нужен вход; другие ошибки не повторяются', () async {
    final authenticationRepository = FakeAuthenticationRepository();
    final authorizationController = AuthorizationController(authenticationRepository: authenticationRepository);
    final repository = FakeVideoRepository(
      infoResults: [
        (failure: const VideoFailure(code: 'private_video', message: 'Это приватное видео.'), data: null),
        (failure: _signInFailure, data: null),
        (failure: null, data: testVideoInfo),
      ],
    );
    final controller = AddVideoController(
      videoRepository: repository,
      ytDlpVideoRepository: FakeYtDlpVideoRepository(),
      authorizationController: authorizationController,
    );

    await authorizationController.checkAuthorization();
    await controller.fetchVideoInfo(_url);

    authenticationRepository.importResult = (failure: null, data: _importedSession(1));
    await authorizationController.importCookies();
    await _settle();

    expect(repository.requestedUrls, [_url]);

    await controller.fetchVideoInfo(_url);

    authenticationRepository.importResult = (failure: null, data: _importedSession(2));
    await authorizationController.importCookies();
    await _settle();

    expect(repository.requestedUrls, [_url, _url, _url]);
    expect(controller.state.videoInfo, testVideoInfo);

    await controller.close();
  });

  test('completeAdding очищает форму и запоминает добавленное видео, clear сбрасывает всё', () async {
    final controller = _controller(FakeVideoRepository(infoResults: [(failure: null, data: testVideoInfo)]));

    await controller.fetchVideoInfo(_url);
    controller.completeAdding();

    expect(controller.state.addedVideo, testVideoInfo);
    expect(controller.state.videoInfo, isNull);
    expect(controller.state.requestedUrl, isEmpty);
    expect(controller.state.canAdd, isFalse);

    controller.dismissAddedVideo();

    expect(controller.state.addedVideo, isNull);

    controller.completeAdding();

    expect(controller.state.addedVideo, isNull);

    controller.clear();

    expect(controller.state, const AddVideoInitialState());
  });
}
