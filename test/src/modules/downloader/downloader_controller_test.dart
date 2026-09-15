import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/shared_controllers/shared_controllers.dart';
import 'package:youtube_downloader/src/modules/downloader/controllers/controllers.dart';

import '../../support/fake_repositories.dart';

const _url = 'https://youtu.be/kgA8JPY2lIA';

const _signInFailure = VideoFailure(code: 'unplayable', message: 'Войдите в аккаунт', needsSignIn: true);

DownloaderController _controller(
  FakeVideoRepository videoRepository, {
  FakeAuthenticationRepository? authenticationRepository,
}) => DownloaderController(
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
    expect(controller.state.isInfoLoading, isFalse);
  });

  test('fetchVideoInfo: пустая ссылка не ищется', () async {
    final repository = FakeVideoRepository();

    await _controller(repository).fetchVideoInfo('   ');

    expect(repository.requestedUrls, isEmpty);
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

  test('download: прогресс, склейка и готовый файл', () async {
    final repository = FakeVideoRepository(
      infoResults: [(failure: null, data: testVideoInfo)],
      downloadResults: [(failure: null, data: r'C:\Downloads\Обзор.mp4')],
      progressToReport: const [
        DownloadProgressModel(DownloadStage.downloading, 42, speed: 1000, eta: 3),
        DownloadProgressModel(DownloadStage.processing, 100),
      ],
    );
    final controller = _controller(repository);
    final jobs = <DownloadJob?>[];

    await controller.fetchVideoInfo(_url);
    controller.selectQuality(QualityModel.audioId);

    final subscription = controller.stream.listen((state) => jobs.add(state.job));
    await controller.download();

    /// События стрима доставляются асинхронно
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(repository.downloads, [(url: testVideoInfo.url, quality: QualityModel.audioId)]);
    expect(jobs, [
      const DownloadJob(status: DownloadJobStatus.downloading, percent: 0),
      const DownloadJob(status: DownloadJobStatus.downloading, percent: 42, speed: 1000, eta: 3),
      const DownloadJob(status: DownloadJobStatus.processing, percent: 100),
      const DownloadJob(status: DownloadJobStatus.done, percent: 100, filePath: r'C:\Downloads\Обзор.mp4'),
    ]);
  });

  test('во время загрузки качество и новый поиск недоступны', () async {
    final gate = Completer<void>();
    final repository = FakeVideoRepository(
      infoResults: [(failure: null, data: testVideoInfo)],
      downloadResults: [(failure: null, data: r'C:\Downloads\Обзор.mp4')],
      downloadGate: gate.future,
    );
    final controller = _controller(repository);

    await controller.fetchVideoInfo(_url);

    final download = controller.download();

    expect(controller.state.isJobActive, isTrue);

    controller.selectQuality('2160');
    await controller.fetchVideoInfo(_url);

    expect(controller.state.selectedQualityId, '1080');
    expect(repository.requestedUrls, [_url]);

    gate.complete();
    await download;

    expect(controller.state.job?.status, DownloadJobStatus.done);
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
