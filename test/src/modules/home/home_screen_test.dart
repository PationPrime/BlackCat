import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/widgets/widgets.dart';
import 'package:youtube_downloader/src/modules/dependencies/module.dart';
import 'package:youtube_downloader/src/modules/home/module.dart';

import '../../support/fake_repositories.dart';
import '../../support/test_app.dart';
import '../../support/test_localization.dart';

const _url = 'https://youtu.be/kgA8JPY2lIA';
const _otherUrl = 'https://youtu.be/otherVideo1';

const _signInFailure = VideoFailure(
  code: 'bot_check',
  message: 'YouTube просит подтвердить, что вы не бот.',
  needsSignIn: true,
);

void main() {
  setUpAll(loadTestTranslations);

  testWidgets('поиск по Enter в поле ссылки: обычный и цифровой Enter', (tester) async {
    final app = TestApp(
      ytDlpVideoRepository: FakeYtDlpVideoRepository(
        infoResults: [(failure: null, data: testVideoInfo), (failure: null, data: testVideoInfo)],
      ),
    );

    await app.pumpPage(tester, const HomeScreen());
    await app.dependenciesController.check();

    expect(find.text('Главная'), findsOneWidget);

    await tester.enterText(find.byType(TextField), _url);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await app.settle(tester);

    expect(app.ytDlpVideoRepository.requestedUrls, [_url]);
    expect(find.byType(VideoCard), findsOneWidget);

    await tester.enterText(find.byType(TextField), _otherUrl);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    await app.settle(tester);

    expect(app.ytDlpVideoRepository.requestedUrls, [_url, _otherUrl]);

    await app.close();
  });

  testWidgets('пустая ссылка по Enter не ищется', (tester) async {
    final app = TestApp();

    await app.pumpPage(tester, const HomeScreen());
    await tester.enterText(find.byType(TextField), '   ');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await app.settle(tester);

    expect(app.ytDlpVideoRepository.requestedUrls, isEmpty);
    expect(app.videoRepository.requestedUrls, isEmpty);

    await app.close();
  });

  testWidgets('найденное видео добавляется в загрузки: форма очищается, видно подтверждение', (tester) async {
    final app = TestApp(
      ytDlpVideoRepository: FakeYtDlpVideoRepository(
        infoResults: List.filled(3, (failure: null, data: testVideoInfo)),
      ),
    );

    await app.pumpPage(tester, const HomeScreen());
    await app.dependenciesController.check();
    await tester.enterText(find.byType(TextField), _url);
    await tester.tap(find.text('Найти'));
    await app.settle(tester);

    expect(find.text('Обзор'), findsOneWidget);
    expect(find.text('Скачать'), findsOneWidget);

    await tester.tap(find.text('Скачать'));
    await app.settle(tester);

    expect(app.queueController.state.activeTask?.video.title, 'Обзор');
    expect(app.queueController.state.activeTask?.quality.id, '1080');
    expect(app.queueController.state.activeTask?.engine, DownloadEngineModel.ytDlp);
    expect(find.byType(VideoCard), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, isEmpty);
    expect(find.text('«Обзор» добавлено в загрузки.'), findsOneWidget);

    /// The next video goes to the queue
    await tester.enterText(find.byType(TextField), _url);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await app.settle(tester);

    expect(find.text('«Обзор» добавлено в загрузки.'), findsNothing);
    expect(find.text('Добавить в очередь'), findsOneWidget);

    await tester.tap(find.text('Очистить'));
    await app.settle(tester);

    expect(find.byType(VideoCard), findsNothing);

    await tester.enterText(find.byType(TextField), _url);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await app.settle(tester);
    await tester.tap(find.text('Добавить в очередь'));
    await app.settle(tester);

    expect(app.queueController.state.queue, hasLength(1));

    await tester.tap(find.text('Открыть загрузки'));
    await app.settle(tester);

    expect(app.navigationController.state.tab, AppTabModel.downloads);

    await app.close();
  });

  testWidgets('без yt-dlp ищет встроенный загрузчик, «Установить» открывает установку', (tester) async {
    final app = TestApp(setup: const YtDlpSetupModel());

    await app.pumpPage(tester, const HomeScreen());
    await app.dependenciesController.check();
    await app.settle(tester);

    expect(find.text('yt-dlp не установлен: видео скачается встроенным загрузчиком.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), _url);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await app.settle(tester);

    expect(app.videoRepository.requestedUrls, [_url]);
    expect(app.ytDlpVideoRepository.requestedUrls, isEmpty);

    await tester.tap(find.text('Установить'));
    await app.settle(tester);

    expect(find.byType(DependenciesInstallDialog), findsOneWidget);
    expect(app.dependenciesRepository.installs, hasLength(1));

    app.dependenciesRepository.installs.single.succeed();
    await app.settle(tester);
    await tester.tap(find.text('Готово'));
    await app.settle(tester);

    expect(find.text('Поиск через yt-dlp занимает несколько секунд.'), findsOneWidget);

    await app.close();
  });

  testWidgets('ошибка входа: «Войти» и «Импортировать cookies.txt», новые cookies повторяют поиск', (tester) async {
    final app = TestApp(
      videoRepository: FakeVideoRepository(
        infoResults: [
          (failure: _signInFailure, data: null),
          (failure: _signInFailure, data: null),
          (failure: null, data: testVideoInfo),
        ],
      ),
      setup: const YtDlpSetupModel(),
    );

    await app.pumpPage(tester, const HomeScreen());
    await tester.enterText(find.byType(TextField), _url);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await app.settle(tester);

    final banner = find.byType(AppFailureBanner);

    expect(find.descendant(of: banner, matching: find.text('YouTube просит подтвердить, что вы не бот.')), findsOneWidget);
    expect(find.descendant(of: banner, matching: find.text('Войти')), findsOneWidget);

    /// Signing in through the window repeats the search right away
    await tester.tap(find.descendant(of: banner, matching: find.text('Войти')));
    await app.settle(tester);

    expect(app.authenticationRepository.signInCalls, 1);
    expect(app.videoRepository.requestedUrls, [_url, _url]);
    expect(find.descendant(of: banner, matching: find.text('Обновить вход')), findsOneWidget);

    await tester.tap(find.descendant(of: banner, matching: find.text('Импортировать cookies.txt')));
    await app.settle(tester);

    expect(app.navigationController.state.tab, AppTabModel.settings);
    expect(app.navigationController.state.cookiesImport?.returnTab, AppTabModel.home);

    app.authenticationRepository.importResult = (
      failure: null,
      data: AccountSessionModel.cookiesFile(cookiesFilePath: r'C:\cookies.txt', importedAt: DateTime(2026, 9, 16)),
    );
    await app.authorizationController.importCookies();
    await app.settle(tester);

    expect(app.videoRepository.requestedUrls, [_url, _url, _url]);
    expect(find.byType(AppFailureBanner), findsNothing);
    expect(find.text('Обзор'), findsOneWidget);

    await app.close();
  });
}
