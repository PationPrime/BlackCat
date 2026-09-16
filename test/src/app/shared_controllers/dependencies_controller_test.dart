import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/shared_controllers/shared_controllers.dart';

import '../../support/fake_repositories.dart';

const _onlyYtDlp = YtDlpSetupModel(ytDlp: testYtDlp);

Future<void> _settle() async {
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('check: всё установлено — новые видео качает yt-dlp', () async {
    final controller = DependenciesController(dependenciesRepository: FakeDependenciesRepository());

    expect(controller.state.preferredEngine, DownloadEngineModel.builtIn);

    await controller.check();

    expect(controller.state.status, DependenciesStatus.ready);
    expect(controller.state.setup, testReadySetup);
    expect(controller.state.preferredEngine, DownloadEngineModel.ytDlp);
  });

  test('check: без JavaScript-среды yt-dlp не используется', () async {
    final controller = DependenciesController(
      dependenciesRepository: FakeDependenciesRepository(setupResults: [(failure: null, data: _onlyYtDlp)]),
    );

    await controller.check();

    expect(controller.state.status, DependenciesStatus.missing);
    expect(controller.state.setup?.missing, [DependencyKind.jsRuntime]);
    expect(controller.state.preferredEngine, DownloadEngineModel.builtIn);
  });

  test('check: платформа без yt-dlp не проверяется', () async {
    final repository = FakeDependenciesRepository(isSupported: false);
    final controller = DependenciesController(dependenciesRepository: repository);

    await controller.check();

    expect(controller.state.status, DependenciesStatus.unsupported);
    expect(controller.state.status.canInstall, isFalse);
    expect(repository.setupCalls, 0);
  });

  test('install: шаги отмечают установленные программы, итог — готово', () async {
    final repository = FakeDependenciesRepository(
      setupResults: [(failure: null, data: const YtDlpSetupModel())],
    );
    final controller = DependenciesController(dependenciesRepository: repository);

    await controller.check();

    final installed = controller.install();

    await _settle();

    expect(controller.state.status, DependenciesStatus.installing);
    expect(controller.state.installing, [DependencyKind.ytDlp, DependencyKind.jsRuntime]);

    /// A second request while installing is ignored
    expect(await controller.install(), isFalse);
    expect(repository.installs, hasLength(1));

    final install = repository.installs.single;

    install.report(
      const DependencyInstallProgressModel(
        kind: DependencyKind.ytDlp,
        stage: DependencyInstallStage.downloading,
        receivedBytes: 50,
        totalBytes: 200,
      ),
    );

    expect(controller.state.progress?.fraction, 0.25);

    install.report(const DependencyInstallProgressModel(kind: DependencyKind.ytDlp, stage: DependencyInstallStage.done));

    expect(controller.state.installed, {DependencyKind.ytDlp});

    install.succeed();

    expect(await installed, isTrue);
    expect(controller.state.status, DependenciesStatus.ready);
    expect(controller.state.installed, {DependencyKind.ytDlp, DependencyKind.jsRuntime});
    expect(controller.state.progress, isNull);
    expect(controller.state.preferredEngine, DownloadEngineModel.ytDlp);
  });

  test('install: ошибка запоминается, установленное к этому времени учитывается', () async {
    final repository = FakeDependenciesRepository(
      setupResults: [
        (failure: null, data: const YtDlpSetupModel()),
        (failure: null, data: _onlyYtDlp),
      ],
    );
    final controller = DependenciesController(dependenciesRepository: repository);

    await controller.check();

    final installed = controller.install();

    await _settle();

    const failure = DependencyFailure(code: 'download', message: 'Не удалось скачать Deno');

    repository.installs.single.failWith(failure);

    expect(await installed, isFalse);
    expect(controller.state.status, DependenciesStatus.failed);
    expect(controller.state.failure, failure);
    expect(controller.state.setup, _onlyYtDlp);
    expect(controller.state.status.canInstall, isTrue);
    expect(controller.state.preferredEngine, DownloadEngineModel.builtIn);

    /// The retry shows only what is still missing
    final retried = controller.install();

    await _settle();

    expect(controller.state.installing, [DependencyKind.jsRuntime]);
    expect(controller.state.failure, isNull);

    repository.installs.last.succeed();

    expect(await retried, isTrue);
  });

  test('cancelInstall останавливает установку', () async {
    final repository = FakeDependenciesRepository(
      setupResults: [(failure: null, data: const YtDlpSetupModel())],
    );
    final controller = DependenciesController(dependenciesRepository: repository);

    await controller.check();

    final installed = controller.install();

    await _settle();

    controller.cancelInstall();

    expect(await installed, isFalse);
    expect(repository.installs.single.cancellation?.isCancelled, isTrue);
    expect(controller.state.status, DependenciesStatus.failed);
    expect(controller.state.isCanceled, isTrue);
    expect(controller.state.failure?.code, const DependencyErrorCodes().canceled);
  });
}
