import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/shared_controllers/shared_controllers.dart';
import 'package:youtube_downloader/src/app/widgets/widgets.dart';
import 'package:youtube_downloader/src/modules/modules.dart';

import '../../support/fake_repositories.dart';
import '../../support/test_app.dart';
import '../../support/test_localization.dart';

const _url = 'https://youtu.be/kgA8JPY2lIA';

const _signInFailure = VideoFailure(
  code: 'bot_check',
  message: 'YouTube просит подтвердить, что вы не бот.',
  needsSignIn: true,
);

final _navigationBar = find.byType(AppNavigationBar);
final _footer = find.byType(DownloadFooter);

Finder _inNavigationBar(String text) => find.descendant(of: _navigationBar, matching: find.text(text));

Finder _inFooter(Finder finder) => find.descendant(of: _footer, matching: finder);

void main() {
  setUpAll(loadTestTranslations);

  testWidgets('навигационный бар слева переключает главную, загрузки и настройки', (tester) async {
    final app = TestApp();

    await app.pumpApp(tester);

    expect(tester.getTopLeft(_navigationBar), Offset.zero);
    expect(tester.getSize(_navigationBar).width, AppNavigationBar.expandedWidth);
    expect(_inNavigationBar('YT Download'), findsOneWidget);
    expect(_inNavigationBar('Главная'), findsOneWidget);
    expect(_inNavigationBar('Загрузки'), findsOneWidget);
    expect(_inNavigationBar('Настройки'), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(DownloadsScreen), findsNothing);

    await tester.enterText(find.byType(TextField), _url);
    await tester.tap(_inNavigationBar('Загрузки'));
    await app.settle(tester);

    expect(app.navigationController.state.tab, AppTabModel.downloads);
    expect(find.byType(DownloadsScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('АКТИВНАЯ ЗАГРУЗКА'), findsOneWidget);

    await tester.tap(_inNavigationBar('Настройки'));
    await app.settle(tester);

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(CookiesCard), findsOneWidget);

    /// A page keeps its state between visits
    await tester.tap(_inNavigationBar('Главная'));
    await app.settle(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.widgetWithText(TextField, _url), findsOneWidget);

    await app.close();
  });

  testWidgets('вход в YouTube внизу навбара', (tester) async {
    final app = TestApp();

    await app.pumpApp(tester);

    expect(_inNavigationBar('Войти в YouTube'), findsOneWidget);

    await tester.tap(_inNavigationBar('Войти в YouTube'));
    await app.settle(tester);

    expect(app.authenticationRepository.signInCalls, 1);
    expect(_inNavigationBar('Аккаунт подключён'), findsOneWidget);

    await tester.tap(_inNavigationBar('Выйти'));
    await app.settle(tester);

    expect(app.authorizationController.state.isAuthorized, isFalse);
    expect(_inNavigationBar('Войти в YouTube'), findsOneWidget);

    await app.close();
  });

  testWidgets('нижняя панель: текущая загрузка на всех страницах, на всю ширину под навбаром', (tester) async {
    final app = TestApp();

    await app.pumpApp(tester);

    expect(tester.getRect(_footer), const Rect.fromLTRB(0, 900 - DownloadFooter.height, 1200, 900));
    expect(tester.getRect(_navigationBar).bottom, tester.getRect(_footer).top);
    expect(_inFooter(find.text('Нет активных загрузок')), findsOneWidget);

    await app.addTask(tester, 'a');
    await app.addTask(tester, 'b');

    app.videoRepository.downloads.single.reportProgress(
      const DownloadProgressModel(DownloadStage.downloading, 50, speed: 1024, eta: 4, downloadedBytes: 500, totalBytes: 1000),
    );
    await app.settle(tester);

    expect(_inFooter(find.text('Видео a')), findsOneWidget);
    expect(_inFooter(find.text('50%')), findsOneWidget);
    expect(_inFooter(find.textContaining('Скачивание 50%')), findsOneWidget);
    expect(_inFooter(find.textContaining('В очереди: 1')), findsOneWidget);
    expect(_inFooter(find.byType(AppProgressBar)), findsOneWidget);
    expect(_inNavigationBar('2'), findsOneWidget);

    await tester.tap(_inNavigationBar('Настройки'));
    await app.settle(tester);

    expect(_inFooter(find.text('Видео a')), findsOneWidget);

    await tester.tap(_inFooter(find.byTooltip('Пауза')));
    await app.settle(tester);

    expect(app.queueController.state.activeTask?.status, DownloadTaskStatus.paused);
    expect(_inFooter(find.textContaining('На паузе · 50%')), findsOneWidget);

    await tester.tap(_inFooter(find.byTooltip('Продолжить')));
    await app.settle(tester);

    expect(app.queueController.state.activeTask?.status, DownloadTaskStatus.downloading);
    expect(app.navigationController.state.tab, AppTabModel.settings);

    await tester.tap(_inFooter(find.text('Видео a')));
    await app.settle(tester);

    expect(app.navigationController.state.tab, AppTabModel.downloads);
    expect(find.byType(DownloadsScreen), findsOneWidget);

    await app.close();
  });

  testWidgets('в узком окне навбар из одних значков, названия — в подсказках', (tester) async {
    final app = TestApp();

    await app.pumpApp(tester, size: const Size(700, 800));

    expect(tester.getSize(_navigationBar).width, AppNavigationBar.compactWidth);
    expect(_inNavigationBar('Загрузки'), findsNothing);
    expect(find.byTooltip('Загрузки'), findsOneWidget);
    expect(find.byTooltip('Войти в YouTube'), findsOneWidget);

    await tester.tap(find.byTooltip('Настройки'));
    await app.settle(tester);

    expect(app.navigationController.state.tab, AppTabModel.settings);
    expect(tester.takeException(), isNull);

    await app.close();
  });

  testWidgets('yt-dlp не найден: установка поверх страниц, после ошибки импорт cookies ведёт в настройки', (tester) async {
    final app = TestApp(setup: const YtDlpSetupModel());

    await app.pumpApp(tester);
    await app.dependenciesController.check();
    await app.settle(tester);

    expect(find.byType(DependenciesInstallDialog), findsOneWidget);

    app.dependenciesRepository.installs.single.failWith(
      const DependencyFailure(code: 'download', message: 'Не удалось скачать yt-dlp: нет соединения с GitHub.'),
    );
    await app.settle(tester);
    await tester.tap(find.text('Закрыть'));
    await app.settle(tester);

    expect(find.byType(DependenciesFallbackDialog), findsOneWidget);
    expect(find.textContaining('YouTube обычно требует входа'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(DependenciesFallbackDialog), matching: find.text('Импортировать cookies.txt')));
    await app.settle(tester);

    expect(find.byType(DependenciesFallbackDialog), findsNothing);
    expect(app.navigationController.state.tab, AppTabModel.settings);
    expect(tester.widget<CookiesCard>(find.byType(CookiesCard)).highlighted, isTrue);
    expect(find.text('Как получить cookies.txt').hitTestable(), findsOneWidget);

    await app.close();
  });

  testWidgets('установка не удалась, но вход выполнен: «Добавить видео» открывает главную', (tester) async {
    final app = TestApp(setup: const YtDlpSetupModel());

    app.authenticationRepository.restoreResult = (failure: null, data: const AccountSessionModel.signInWindow());
    app.navigationController.selectTab(AppTabModel.downloads);

    await app.pumpApp(tester);
    await app.dependenciesController.check();
    await app.settle(tester);

    app.dependenciesRepository.installs.single.failWith(
      const DependencyFailure(code: 'checksum_mismatch', message: 'Контрольная сумма не совпала.'),
    );
    await app.settle(tester);
    await tester.tap(find.text('Закрыть'));
    await app.settle(tester);

    expect(find.textContaining('вы всё равно можете попробовать скачать видео'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(DependenciesFallbackDialog), matching: find.text('Добавить видео')));
    await app.settle(tester);

    expect(app.navigationController.state.tab, AppTabModel.home);
    expect(find.byType(HomeScreen), findsOneWidget);

    await app.close();
  });

  testWidgets('импорт cookies из поиска: подсвеченная карточка, после импорта — главная и повторный поиск', (tester) async {
    final app = TestApp(
      videoRepository: FakeVideoRepository(
        infoResults: [(failure: _signInFailure, data: null), (failure: null, data: testVideoInfo)],
      ),
      setup: const YtDlpSetupModel(),
    );

    await app.pumpApp(tester);
    await tester.enterText(find.byType(TextField), _url);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await app.settle(tester);
    await tester.tap(find.descendant(of: find.byType(AppFailureBanner), matching: find.text('Импортировать cookies.txt')));
    await app.settle(tester);

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(tester.widget<CookiesCard>(find.byType(CookiesCard)).highlighted, isTrue);
    expect(find.text('Файл не выбран').hitTestable(), findsOneWidget);
    expect(tester.widget<AppNavigationBar>(_navigationBar).selectedIndex, AppTabModel.settings.index);

    await tester.tap(find.text('Подробная инструкция в FAQ yt-dlp'));
    await app.settle(tester);

    expect(app.urlLauncher.opened, ['https://github.com/yt-dlp/yt-dlp/wiki/FAQ#how-do-i-pass-cookies-to-yt-dlp']);

    app.authenticationRepository.importResult = (
      failure: null,
      data: AccountSessionModel.cookiesFile(
        cookiesFilePath: r'C:\Users\user\Downloads\cookies.txt',
        importedAt: DateTime(2026, 9, 16, 14, 30),
      ),
    );

    await tester.tap(find.text('Выбрать cookies.txt…'));
    await app.settle(tester);

    /// Back on the home page the search has repeated with the new cookies
    expect(app.navigationController.state.tab, AppTabModel.home);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(app.videoRepository.requestedUrls, [_url, _url]);
    expect(find.text('Обзор'), findsOneWidget);
    expect(find.byType(AppFailureBanner), findsNothing);
    expect(_inNavigationBar('Аккаунт подключён'), findsOneWidget);

    await tester.tap(_inNavigationBar('Настройки'));
    await app.settle(tester);

    expect(tester.widget<CookiesCard>(find.byType(CookiesCard)).highlighted, isFalse);
    expect(find.text(r'C:\Users\user\Downloads\cookies.txt'), findsOneWidget);
    expect(find.text('Используется'), findsOneWidget);

    await app.close();
  });
}
