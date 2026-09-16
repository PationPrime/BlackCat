import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/src/app/design_system/design_system.dart';
import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/repositories/repositories.dart';
import 'package:youtube_downloader/src/app/services/services.dart';
import 'package:youtube_downloader/src/app/shared_controllers/shared_controllers.dart';
import 'package:youtube_downloader/src/app/widgets/widgets.dart';
import 'package:youtube_downloader/src/modules/downloader/module.dart';

import '../../support/fake_repositories.dart';
import '../../support/test_localization.dart';

const _quality = QualityModel(id: '1080', kind: QualityKind.video, label: '1080p', resolution: 1080);

VideoInfoModel _video(String id) => VideoInfoModel(
  id: id,
  title: 'Видео $id',
  url: 'https://www.youtube.com/watch?v=$id',
  qualities: const [_quality],
);

const _url = 'https://youtu.be/kgA8JPY2lIA';

const _signInFailure = VideoFailure(
  code: 'bot_check',
  message: 'YouTube просит подтвердить, что вы не бот.',
  needsSignIn: true,
);

const _missingSetup = YtDlpSetupModel();

final class _Screen {
  final FakeVideoRepository videoRepository;
  final ytDlpVideoRepository = FakeYtDlpVideoRepository(
    infoResults: [(failure: null, data: testVideoInfo)],
  );
  final settingsRepository = FakeSettingsRepository();
  final queueRepository = FakeDownloadQueueRepository();
  final authenticationRepository = FakeAuthenticationRepository();
  final FakeDependenciesRepository dependenciesRepository;
  late final authorizationController = AuthorizationController(
    authenticationRepository: authenticationRepository,
  );
  late final dependenciesController = DependenciesController(
    dependenciesRepository: dependenciesRepository,
  );

  _Screen({
    FakeVideoRepository? videoRepository,
    YtDlpSetupModel setup = testReadySetup,
  }) : videoRepository =
           videoRepository ?? FakeVideoRepository(infoResults: [(failure: null, data: testVideoInfo)]),
       dependenciesRepository = FakeDependenciesRepository(
         setupResults: [(failure: null, data: setup)],
       );
  late final controller = DownloadQueueController(
    downloadQueueRepository: queueRepository,
    videoRepository: videoRepository,
    ytDlpVideoRepository: ytDlpVideoRepository,
    settingsRepository: settingsRepository,
    authorizationController: authorizationController,
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1000, 1800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await authorizationController.checkAuthorization();
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<FileSystemService>.value(value: FileSystemServiceImpl()),
          RepositoryProvider<VideoRepositoryInterface>.value(value: videoRepository),
          RepositoryProvider<YtDlpVideoRepositoryInterface>.value(value: ytDlpVideoRepository),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<AuthorizationController>.value(value: authorizationController),
            BlocProvider<DownloadQueueController>.value(value: controller),
            BlocProvider<DependenciesController>.value(value: dependenciesController),
          ],
          child: MaterialApp(theme: AppThemeData.darkTheme, home: const DownloaderScreen()),
        ),
      ),
    );
  }

  Future<void> add(WidgetTester tester, String id) async {
    await controller.addTask(video: _video(id), quality: _quality);
    await settle(tester);
  }

  /// Enough both for the queue change chain and for the dialog open and close animation
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
}

void main() {
  setUpAll(loadTestTranslations);

  testWidgets('разделы: активная загрузка, очередь и завершённые', (tester) async {
    final screen = _Screen();

    await screen.pump(tester);

    expect(find.text('АКТИВНАЯ ЗАГРУЗКА'), findsOneWidget);
    expect(find.text('ОЧЕРЕДЬ СКАЧИВАНИЯ'), findsOneWidget);
    expect(find.textContaining('Нет активной загрузки'), findsOneWidget);
    expect(find.textContaining('Очередь пуста'), findsOneWidget);
    expect(find.text('СКАЧАННЫЕ'), findsOneWidget);
    expect(find.text('Здесь появятся скачанные видео.'), findsOneWidget);

    await screen.add(tester, 'a');
    await screen.add(tester, 'b');
    await screen.add(tester, 'c');

    screen.videoRepository.downloads.single.reportProgress(
      const DownloadProgressModel(DownloadStage.downloading, 50, speed: 1024, eta: 4, downloadedBytes: 500, totalBytes: 1000),
    );
    await screen.settle(tester);

    expect(find.text('Видео a'), findsOneWidget);
    expect(find.textContaining('Скачивание 50%'), findsOneWidget);
    expect(find.text('Видео b'), findsOneWidget);
    expect(find.text('Видео c'), findsOneWidget);
    expect(find.byType(QueuedDownloadTile), findsNWidgets(2));
    expect(find.textContaining('Очередь пуста'), findsNothing);

    screen.videoRepository.downloads.single.succeed(r'C:\Downloads\a.mp4', sizeBytes: 70000000);
    await screen.settle(tester);

    expect(find.byType(DownloadedVideoTile), findsOneWidget);
    expect(find.textContaining('67 МБ · Скачано '), findsOneWidget);
    expect(find.text('Здесь появятся скачанные видео.'), findsNothing);
    expect(find.byType(ActiveDownloadCard), findsOneWidget);
    expect(find.byType(QueuedDownloadTile), findsOneWidget);

    await screen.controller.close();
  });

  testWidgets('удаление начатой загрузки спрашивает подтверждение', (tester) async {
    final screen = _Screen();

    await screen.pump(tester);
    await screen.add(tester, 'a');

    screen.videoRepository.downloads.single.reportProgress(
      const DownloadProgressModel(DownloadStage.downloading, 30, downloadedBytes: 300, totalBytes: 1000),
    );
    await screen.settle(tester);

    await tester.tap(find.descendant(of: find.byType(ActiveDownloadCard), matching: find.byTooltip('Убрать')));
    await screen.settle(tester);

    expect(find.text('Убрать видео?'), findsOneWidget);

    await tester.tap(find.text('Отмена'));
    await screen.settle(tester);

    expect(find.text('Убрать видео?'), findsNothing);
    expect(screen.controller.state.activeTask?.video.id, 'a');

    await tester.tap(find.descendant(of: find.byType(ActiveDownloadCard), matching: find.byTooltip('Убрать')));
    await screen.settle(tester);
    await tester.tap(find.text('Убрать и удалить файл'));
    await screen.settle(tester);

    expect(screen.controller.state.activeTask, isNull);
    expect(screen.queueRepository.removedTaskIds, hasLength(1));

    await screen.controller.close();
  });

  testWidgets('«Скачать сейчас» в очереди делает видео активным', (tester) async {
    final screen = _Screen();

    await screen.pump(tester);
    await screen.add(tester, 'a');
    await screen.add(tester, 'b');

    await tester.tap(find.byTooltip('Скачать сейчас'));
    await screen.settle(tester);

    expect(screen.controller.state.activeTask?.video.id, 'b');
    expect(find.textContaining('На паузе'), findsOneWidget);

    await screen.controller.close();
  });

  testWidgets('«Добавить видео» открывает диалог поиска', (tester) async {
    final screen = _Screen();

    await screen.pump(tester);

    await tester.tap(find.text('Добавить видео'));
    await screen.settle(tester);

    expect(find.byType(AddVideoDialog), findsOneWidget);
    expect(find.text('Найти'), findsOneWidget);

    await tester.tap(find.text('Отмена'));
    await screen.settle(tester);

    expect(find.byType(AddVideoDialog), findsNothing);

    await screen.controller.close();
  });

  testWidgets('yt-dlp установлен: окна установки нет, новые видео ищутся через yt-dlp', (tester) async {
    final screen = _Screen();

    await screen.pump(tester);
    await screen.dependenciesController.check();
    await screen.settle(tester);

    expect(find.byType(DependenciesInstallDialog), findsNothing);

    await tester.tap(find.text('Добавить видео'));
    await screen.settle(tester);

    expect(find.text('Поиск через yt-dlp занимает несколько секунд.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), _url);
    await tester.tap(find.text('Найти'));
    await screen.settle(tester);

    expect(screen.ytDlpVideoRepository.requestedUrls, [_url]);
    expect(screen.videoRepository.requestedUrls, isEmpty);

    await tester.tap(find.text('Отмена'));
    await screen.settle(tester);
    await screen.controller.close();
  });

  testWidgets('yt-dlp не найден: сразу идёт установка с прогрессом, после ошибки — окно про встроенный загрузчик', (tester) async {
    final screen = _Screen(setup: _missingSetup);

    await screen.pump(tester);
    await screen.dependenciesController.check();
    await screen.settle(tester);

    expect(find.byType(DependenciesInstallDialog), findsOneWidget);
    expect(find.text('Установка yt-dlp'), findsOneWidget);
    expect(screen.dependenciesRepository.installs, hasLength(1));
    expect(find.text('Подготовка…'), findsOneWidget);
    expect(find.text('Ожидает'), findsOneWidget);

    final install = screen.dependenciesRepository.installs.single;

    install.report(
      const DependencyInstallProgressModel(
        kind: DependencyKind.ytDlp,
        stage: DependencyInstallStage.downloading,
        receivedBytes: 5 << 20,
        totalBytes: 17 << 20,
      ),
    );
    await screen.settle(tester);

    expect(find.textContaining('Скачивание: 5'), findsOneWidget);
    expect(find.byType(AppProgressBar), findsOneWidget);
    expect(find.text('Отменить'), findsOneWidget);

    install.report(const DependencyInstallProgressModel(kind: DependencyKind.ytDlp, stage: DependencyInstallStage.done));
    install.report(const DependencyInstallProgressModel(kind: DependencyKind.jsRuntime, stage: DependencyInstallStage.extracting));
    await screen.settle(tester);

    expect(find.text('Установлен'), findsOneWidget);
    expect(find.text('Распаковка…'), findsOneWidget);

    install.failWith(const DependencyFailure(code: 'download', message: 'Не удалось скачать Deno: нет соединения с GitHub.'));
    await screen.settle(tester);

    expect(find.text('Не удалось скачать Deno: нет соединения с GitHub.'), findsOneWidget);
    expect(find.text('Не установлен'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);

    await tester.tap(find.text('Закрыть'));
    await screen.settle(tester);

    expect(find.byType(DependenciesInstallDialog), findsNothing);
    expect(find.byType(DependenciesFallbackDialog), findsOneWidget);
    expect(find.textContaining('YouTube обычно требует входа'), findsOneWidget);
    expect(find.text('Причина: Не удалось скачать Deno: нет соединения с GitHub.'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
    expect(find.text('Импортировать cookies.txt'), findsOneWidget);

    await tester.tap(find.text('Закрыть'));
    await screen.settle(tester);

    expect(find.byType(DependenciesFallbackDialog), findsNothing);

    /// Without yt-dlp the built-in downloader searches
    await tester.tap(find.text('Добавить видео'));
    await screen.settle(tester);

    expect(find.text('yt-dlp не установлен: видео скачается встроенным загрузчиком.'), findsOneWidget);
    expect(find.text('Установить'), findsOneWidget);

    await tester.enterText(find.byType(TextField), _url);
    await tester.tap(find.text('Найти'));
    await screen.settle(tester);

    expect(screen.videoRepository.requestedUrls, [_url]);
    expect(screen.ytDlpVideoRepository.requestedUrls, isEmpty);

    /// «Установить» opens the installation again
    await tester.tap(find.text('Установить'));
    await screen.settle(tester);

    expect(find.byType(DependenciesInstallDialog), findsOneWidget);
    expect(screen.dependenciesRepository.installs, hasLength(2));

    screen.dependenciesRepository.installs.last.succeed();
    await screen.settle(tester);

    expect(find.text('Готово: видео будут скачиваться через yt-dlp 2026.08.19.'), findsOneWidget);

    await tester.tap(find.text('Готово'));
    await screen.settle(tester);

    expect(find.byType(DependenciesInstallDialog), findsNothing);
    expect(find.text('Поиск через yt-dlp занимает несколько секунд.'), findsOneWidget);

    await tester.tap(find.text('Отмена'));
    await screen.settle(tester);
    await screen.controller.close();
  });

  testWidgets('установка не удалась, но вход выполнен: можно сразу добавить видео', (tester) async {
    final screen = _Screen(setup: _missingSetup);

    screen.authenticationRepository.restoreResult = (failure: null, data: const AccountSessionModel.signInWindow());

    await screen.pump(tester);
    await screen.dependenciesController.check();
    await screen.settle(tester);

    screen.dependenciesRepository.installs.single.failWith(
      const DependencyFailure(code: 'checksum_mismatch', message: 'Контрольная сумма не совпала.'),
    );
    await screen.settle(tester);
    await tester.tap(find.text('Закрыть'));
    await screen.settle(tester);

    expect(find.textContaining('вы всё равно можете попробовать скачать видео'), findsOneWidget);
    expect(find.text('Войти'), findsNothing);

    await tester.tap(
      find.descendant(of: find.byType(DependenciesFallbackDialog), matching: find.text('Добавить видео')),
    );
    await screen.settle(tester);

    expect(find.byType(DependenciesFallbackDialog), findsNothing);
    expect(find.byType(AddVideoDialog), findsOneWidget);

    await tester.tap(find.text('Отмена'));
    await screen.settle(tester);
    await screen.controller.close();
  });

  testWidgets('ошибка, для которой нужен вход: в очереди кнопки «Войти» и «Импортировать cookies.txt»', (tester) async {
    final screen = _Screen();

    await screen.pump(tester);
    await screen.add(tester, 'a');

    screen.videoRepository.downloads.single.failWith(_signInFailure);
    await screen.settle(tester);

    final failure = find.byType(DownloadTaskFailure);

    expect(failure, findsOneWidget);
    expect(find.descendant(of: failure, matching: find.text('Войти')), findsOneWidget);
    expect(find.descendant(of: failure, matching: find.text('Импортировать cookies.txt')), findsOneWidget);

    await tester.tap(find.descendant(of: failure, matching: find.text('Войти')));
    await screen.settle(tester);

    expect(screen.authenticationRepository.signInCalls, 1);
    expect(screen.videoRepository.downloads, hasLength(2));

    await screen.controller.close();
  });

  testWidgets('ошибка поиска, для которой нужен вход: в диалоге кнопки «Войти» и «Импортировать cookies.txt»', (tester) async {
    final screen = _Screen(
      videoRepository: FakeVideoRepository(
        infoResults: [(failure: _signInFailure, data: null), (failure: null, data: testVideoInfo)],
      ),
      setup: _missingSetup,
    );

    await screen.pump(tester);
    await tester.tap(find.text('Добавить видео'));
    await screen.settle(tester);
    await tester.enterText(find.byType(TextField), _url);
    await tester.tap(find.text('Найти'));
    await screen.settle(tester);

    final banner = find.byType(AppFailureBanner);

    expect(find.descendant(of: banner, matching: find.text('YouTube просит подтвердить, что вы не бот.')), findsOneWidget);
    expect(find.descendant(of: banner, matching: find.text('Войти')), findsOneWidget);
    expect(find.descendant(of: banner, matching: find.text('Импортировать cookies.txt')), findsOneWidget);

    await tester.tap(find.descendant(of: banner, matching: find.text('Войти')));
    await screen.settle(tester);

    expect(screen.authenticationRepository.signInCalls, 1);
    expect(screen.videoRepository.requestedUrls, [_url, _url]);
    expect(find.byType(AppFailureBanner), findsNothing);
    expect(find.text('Обзор'), findsOneWidget);

    await tester.tap(find.text('Отмена'));
    await screen.settle(tester);
    await screen.controller.close();
  });
}
