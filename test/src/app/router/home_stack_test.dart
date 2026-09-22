import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peeky_cat/src/app/errors/errors.dart';
import 'package:peeky_cat/src/app/models/models.dart';
import 'package:peeky_cat/src/app/shared_controllers/shared_controllers.dart';
import 'package:peeky_cat/src/app/widgets/widgets.dart';
import 'package:peeky_cat/src/modules/modules.dart';

import '../../support/fake_repositories.dart';
import '../../support/test_app.dart';
import '../../support/test_localization.dart';

const _url = 'https://youtu.be/kgA8JPY2lIA';

const _signInFailure = VideoFailure(
  code: 'bot_check',
  message: 'YouTube просит подтвердить, что вы не бот.',
  needsSignIn: true,
);

/// The page has a second link field, for downloading any file: the search
/// is the one in the search form
final _searchField = find.descendant(
  of: find.byType(UrlSearchForm),
  matching: find.byType(TextField),
);

final _navigationBar = find.byType(AppNavigationBar);
final _footer = find.byType(DownloadFooter);

Finder _inNavigationBar(String text) =>
    find.descendant(of: _navigationBar, matching: find.text(text));

Finder _inFooter(Finder finder) =>
    find.descendant(of: _footer, matching: finder);

void main() {
  setUpAll(loadTestTranslations);

  testWidgets(
    'навигационный бар слева переключает главную, загрузки и настройки',
    (tester) async {
      final app = TestApp();

      await app.pumpApp(tester);

      expect(tester.getTopLeft(_navigationBar), Offset.zero);
      expect(
        tester.getSize(_navigationBar).width,
        AppNavigationBar.expandedWidth,
      );
      expect(_inNavigationBar('PeekyCat'), findsOneWidget);
      expect(
        find.descendant(of: _navigationBar, matching: find.byType(AppIconLogo)),
        findsOneWidget,
      );
      expect(_inNavigationBar('Главная'), findsOneWidget);
      expect(_inNavigationBar('Загрузки'), findsOneWidget);
      expect(_inNavigationBar('Настройки'), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(DownloadsScreen), findsNothing);

      await tester.enterText(_searchField, _url);
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
    },
  );

  testWidgets(
    'на главной вкладки сайтов: YouTube по умолчанию, RuTube, TikTok, Instagram и X рядом, поиск каждой сохраняется',
    (tester) async {
      final app = TestApp();

      await app.pumpApp(tester);

      final tabs = find.byType(HomeSourceTabs);

      expect(
        find.descendant(of: tabs, matching: find.text('YouTube')),
        findsOneWidget,
      );
      expect(find.byType(YouTubeDownloadScreen), findsOneWidget);
      expect(find.byType(RuTubeDownloadScreen), findsNothing);

      await tester.enterText(_searchField, _url);
      await tester.tap(
        find.descendant(of: tabs, matching: find.text('RuTube')),
      );
      await app.settle(tester);

      expect(find.byType(RuTubeDownloadScreen), findsOneWidget);
      expect(find.text('https://rutube.ru/video/...'), findsOneWidget);

      await tester.tap(
        find.descendant(of: tabs, matching: find.text('TikTok')),
      );
      await app.settle(tester);

      expect(find.byType(TikTokDownloadScreen), findsOneWidget);
      expect(
        find.text('https://www.tiktok.com/@user/video/...'),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(of: tabs, matching: find.text('Instagram')),
      );
      await app.settle(tester);

      expect(find.byType(InstagramDownloadScreen), findsOneWidget);
      expect(find.text('https://www.instagram.com/reel/...'), findsOneWidget);

      await tester.tap(find.descendant(of: tabs, matching: find.text('X')));
      await app.settle(tester);

      expect(find.byType(XDownloadScreen), findsOneWidget);
      expect(find.text('https://x.com/user/status/...'), findsOneWidget);

      await tester.tap(
        find.descendant(of: tabs, matching: find.text('YouTube')),
      );
      await app.settle(tester);

      expect(find.byType(YouTubeDownloadScreen), findsOneWidget);
      expect(find.widgetWithText(TextField, _url), findsOneWidget);

      await app.close();
    },
  );

  testWidgets(
    'вход в YouTube — в заголовке главной, а не в навбаре: cookies первыми, Google — после предупреждения',
    (tester) async {
      final app = TestApp();

      await app.pumpApp(tester);

      final header = find.descendant(
        of: find.byType(HomeScreen),
        matching: find.byType(AppPageHeader),
      );
      final signIn = find.descendant(
        of: header,
        matching: find.text('Войти через Google'),
      );

      expect(
        find.descendant(of: header, matching: find.text('Добавить cookies')),
        findsOneWidget,
      );
      expect(signIn, findsOneWidget);
      expect(_inNavigationBar('Войти через Google'), findsNothing);
      expect(_inNavigationBar('Добавить cookies'), findsNothing);

      await tester.tap(signIn);
      await app.settle(tester);
      await tester.tap(find.text('Всё равно войти через Google'));
      await app.settle(tester);

      expect(app.authenticationRepository.signInCalls, 1);
      expect(
        find.descendant(of: header, matching: find.text('Вход через Google')),
        findsOneWidget,
      );

      await app.close();
    },
  );

  testWidgets(
    'нижняя панель: текущая загрузка поверх низа всех страниц, навбар не перекрывает',
    (tester) async {
      final app = TestApp();

      await app.pumpApp(tester);

      final navigationBarRect = tester.getRect(_navigationBar);

      expect(
        navigationBarRect,
        const Rect.fromLTRB(0, 0, AppNavigationBar.expandedWidth, 900),
      );
      expect(
        tester.getRect(_footer),
        const Rect.fromLTRB(
          AppNavigationBar.expandedWidth,
          900 - DownloadFooter.height,
          1200,
          900,
        ),
      );
      expect(_inFooter(find.text('Нет активных загрузок')), findsOneWidget);

      await app.addTask(tester, 'a');
      await app.addTask(tester, 'b');

      app.videoRepository.downloads.single.reportProgress(
        const DownloadProgressModel(
          DownloadStage.downloading,
          50,
          speed: 1024,
          eta: 4,
          downloadedBytes: 500,
          totalBytes: 1000,
        ),
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

      expect(
        app.queueController.state.activeTask?.status,
        DownloadTaskStatus.paused,
      );
      expect(_inFooter(find.textContaining('На паузе · 50%')), findsOneWidget);

      await tester.tap(_inFooter(find.byTooltip('Продолжить')));
      await app.settle(tester);

      expect(
        app.queueController.state.activeTask?.status,
        DownloadTaskStatus.downloading,
      );
      expect(app.navigationController.state.tab, AppTabModel.settings);

      await tester.tap(_inFooter(find.text('Видео a')));
      await app.settle(tester);

      expect(app.navigationController.state.tab, AppTabModel.downloads);
      expect(find.byType(DownloadsScreen), findsOneWidget);

      await app.close();
    },
  );

  testWidgets(
    'фон — одна лава под всеми страницами, под видео на весь экран она замирает',
    (tester) async {
      final app = TestApp();
      final background = find.byType(AppLavaBackground);

      await app.pumpApp(tester);

      expect(background, findsOneWidget);
      expect(
        tester.getRect(background),
        const Rect.fromLTRB(AppNavigationBar.expandedWidth, 0, 1200, 900),
      );
      expect(tester.widget<AppLavaBackground>(background).animate, isTrue);

      await tester.tap(_inNavigationBar('Настройки'));
      await app.settle(tester);

      expect(background, findsOneWidget);
      expect(
        find.ancestor(of: find.byType(SettingsScreen), matching: background),
        findsNothing,
      );

      await app.appWindowController.setFullScreen(true);
      await app.settle(tester);

      expect(tester.widget<AppLavaBackground>(background).animate, isFalse);

      await app.appWindowController.setFullScreen(false);
      await app.settle(tester);

      expect(tester.widget<AppLavaBackground>(background).animate, isTrue);

      await app.close();
    },
  );

  testWidgets('низ страницы прокручивается из-под нижней панели', (
    tester,
  ) async {
    final app = TestApp();

    await app.pumpApp(tester, size: const Size(1200, 520));
    await app.addTask(tester, 'a');
    await app.addTask(tester, 'b');
    await tester.tap(_inNavigationBar('Загрузки'));
    await app.settle(tester);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await app.settle(tester);

    final placeholder = find.ancestor(
      of: find.text('Здесь появятся скачанные видео.'),
      matching: find.byType(DownloadsEmptyPlaceholder),
    );

    expect(
      tester.getRect(placeholder).bottom,
      lessThanOrEqualTo(tester.getRect(_footer).top),
    );

    await app.close();
  });

  testWidgets('«Поддержать» в навбаре открывает страницу поддержки', (
    tester,
  ) async {
    final app = TestApp();

    await app.pumpApp(tester);
    await tester.tap(_inNavigationBar('Поддержать'));
    await app.settle(tester);

    expect(app.navigationController.state.tab, AppTabModel.donations);
    expect(find.byType(DonationsScreen), findsOneWidget);
    expect(find.byType(DonationPlatformCard), findsNWidgets(3));

    await app.close();
  });

  testWidgets('в окне наименьшего размера видны вкладки всех сайтов', (
    tester,
  ) async {
    const titles = ['YouTube', 'TikTok', 'Instagram', 'X', 'RuTube'];

    /// The pages of the smallest window: its width without the navigation
    /// bar of icons
    final width =
        AppWindowController.minimumSize.width - AppNavigationBar.compactWidth;
    final selected = <int>[];
    final app = TestApp();

    await app.pumpPage(
      tester,
      Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: HomeSourceTabs(
            titles: titles,
            selectedIndex: 0,
            onSelected: selected.add,
          ),
        ),
      ),
      size: Size(width, AppWindowController.minimumSize.height),
    );

    expect(tester.takeException(), isNull);

    for (final title in titles) {
      final tab = find.text(title);

      expect(tester.getRect(tab).left, greaterThanOrEqualTo(0));
      expect(tester.getRect(tab).right, lessThanOrEqualTo(width));
    }

    await tester.tap(find.text('RuTube'));

    expect(selected, [4]);

    await app.close();
  });

  testWidgets('в узком окне навбар из одних значков, названия — в подсказках', (
    tester,
  ) async {
    final app = TestApp();

    await app.pumpApp(tester, size: const Size(700, 800));

    expect(tester.getSize(_navigationBar).width, AppNavigationBar.compactWidth);
    expect(tester.getRect(_footer).left, AppNavigationBar.compactWidth);
    expect(_inNavigationBar('Загрузки'), findsNothing);
    expect(find.byTooltip('Загрузки'), findsOneWidget);

    /// Without the app name the icon names it in a tooltip
    expect(
      find.descendant(
        of: find.byTooltip('PeekyCat'),
        matching: find.byType(AppIconLogo),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Настройки'));
    await app.settle(tester);

    expect(app.navigationController.state.tab, AppTabModel.settings);
    expect(tester.takeException(), isNull);

    await app.close();
  });

  testWidgets(
    'yt-dlp не найден: установка поверх страниц, после ошибки импорт cookies ведёт в настройки',
    (tester) async {
      final app = TestApp(setup: const YtDlpSetupModel());

      await app.pumpApp(tester);
      await app.dependenciesController.check();
      await app.settle(tester);

      expect(find.byType(DependenciesInstallDialog), findsOneWidget);

      app.dependenciesRepository.installs.single.failWith(
        const DependencyFailure(
          code: 'download',
          message: 'Не удалось скачать yt-dlp: нет соединения с GitHub.',
        ),
      );
      await app.settle(tester);
      await tester.tap(find.text('Закрыть'));
      await app.settle(tester);

      expect(find.byType(DependenciesFallbackDialog), findsOneWidget);
      expect(
        find.textContaining('YouTube обычно требует входа'),
        findsOneWidget,
      );

      /// Cookies are the main button, the Google window is next to it
      expect(
        find.descendant(
          of: find.byType(DependenciesFallbackDialog),
          matching: find.widgetWithText(AppPrimaryButton, 'Добавить cookies'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(DependenciesFallbackDialog),
          matching: find.text('Войти через Google'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(DependenciesFallbackDialog),
          matching: find.text('Добавить cookies'),
        ),
      );
      await app.settle(tester);

      expect(find.byType(DependenciesFallbackDialog), findsNothing);
      expect(app.navigationController.state.tab, AppTabModel.settings);
      expect(
        tester.widget<CookiesCard>(find.byType(CookiesCard)).highlighted,
        isTrue,
      );
      expect(
        find.text('Как получить и добавить cookies').hitTestable(),
        findsOneWidget,
      );

      await app.close();
    },
  );

  testWidgets(
    'установка не удалась: вход через Google из диалога — только после предупреждения',
    (tester) async {
      final app = TestApp(setup: const YtDlpSetupModel());

      await app.pumpApp(tester);
      await app.dependenciesController.check();
      await app.settle(tester);

      app.dependenciesRepository.installs.single.failWith(
        const DependencyFailure(
          code: 'download',
          message: 'Не удалось скачать yt-dlp: нет соединения с GitHub.',
        ),
      );
      await app.settle(tester);
      await tester.tap(find.text('Закрыть'));
      await app.settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(DependenciesFallbackDialog),
          matching: find.text('Войти через Google'),
        ),
      );
      await app.settle(tester);

      expect(find.byType(AppGoogleSignInDialog), findsOneWidget);
      expect(app.authenticationRepository.signInCalls, 0);

      await tester.tap(find.text('Всё равно войти через Google'));
      await app.settle(tester);

      expect(app.authenticationRepository.signInCalls, 1);

      await app.close();
    },
  );

  testWidgets(
    'установка не удалась, но вход выполнен: «Добавить видео» открывает главную',
    (tester) async {
      final app = TestApp(setup: const YtDlpSetupModel());

      app.authenticationRepository.restoreResult = (
        failure: null,
        data: const AccountSessionModel.signInWindow(),
      );
      app.navigationController.selectTab(AppTabModel.downloads);

      await app.pumpApp(tester);
      await app.dependenciesController.check();
      await app.settle(tester);

      app.dependenciesRepository.installs.single.failWith(
        const DependencyFailure(
          code: 'checksum_mismatch',
          message: 'Контрольная сумма не совпала.',
        ),
      );
      await app.settle(tester);
      await tester.tap(find.text('Закрыть'));
      await app.settle(tester);

      expect(
        find.textContaining('вы всё равно можете попробовать скачать видео'),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(DependenciesFallbackDialog),
          matching: find.text('Добавить видео'),
        ),
      );
      await app.settle(tester);

      expect(app.navigationController.state.tab, AppTabModel.home);
      expect(find.byType(HomeScreen), findsOneWidget);

      await app.close();
    },
  );

  testWidgets(
    'импорт cookies из поиска: подсвеченная карточка, после импорта — главная и повторный поиск',
    (tester) async {
      final app = TestApp(
        videoRepository: FakeVideoRepository(
          infoResults: [
            (failure: _signInFailure, data: null),
            (failure: null, data: testVideoInfo),
          ],
        ),
        setup: const YtDlpSetupModel(),
      );

      await app.pumpApp(tester);
      await tester.enterText(_searchField, _url);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await app.settle(tester);
      final addCookies = find.descendant(
        of: find.byType(AppFailureBanner),
        matching: find.text('Добавить cookies'),
      );

      /// The advice to use cookies stands above the error: it scrolls into view
      await tester.ensureVisible(addCookies);
      await app.settle(tester);
      await tester.tap(addCookies);
      await app.settle(tester);

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(
        tester.widget<CookiesCard>(find.byType(CookiesCard)).highlighted,
        isTrue,
      );

      /// The card opens at its instructions
      expect(
        find.text('Как получить и добавить cookies').hitTestable(),
        findsOneWidget,
      );
      expect(
        tester.widget<AppNavigationBar>(_navigationBar).selectedIndex,
        AppTabModel.settings.index,
      );

      final guide = find.text('Подробная инструкция в FAQ yt-dlp');

      await tester.ensureVisible(guide);
      await app.settle(tester);
      await tester.tap(guide);
      await app.settle(tester);

      expect(app.urlLauncher.opened, [
        'https://github.com/yt-dlp/yt-dlp/wiki/FAQ#how-do-i-pass-cookies-to-yt-dlp',
      ]);

      app.authenticationRepository.importResult = (
        failure: null,
        data: AccountSessionModel.cookiesFile(
          cookiesFilePath: r'C:\Users\user\Downloads\cookies.txt',
          importedAt: DateTime(2026, 9, 16, 14, 30),
        ),
      );

      final choose = find.text('Выбрать cookies.txt…');

      await tester.ensureVisible(choose);
      await app.settle(tester);
      await tester.tap(choose);
      await app.settle(tester);

      /// Back on the home page the search has repeated with the new cookies
      expect(app.navigationController.state.tab, AppTabModel.home);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(app.videoRepository.requestedUrls, [_url, _url]);
      expect(find.text('Обзор'), findsOneWidget);
      expect(find.byType(AppFailureBanner), findsNothing);
      expect(
        find.descendant(
          of: find.byType(HomeScreen),
          matching: find.text('Cookies подключены'),
        ),
        findsOneWidget,
      );

      await tester.tap(_inNavigationBar('Настройки'));
      await app.settle(tester);

      expect(
        tester.widget<CookiesCard>(find.byType(CookiesCard)).highlighted,
        isFalse,
      );
      expect(find.text(r'C:\Users\user\Downloads\cookies.txt'), findsOneWidget);
      expect(find.text('Используется'), findsOneWidget);

      await app.close();
    },
  );

  testWidgets(
    '«Плеер» в навбаре после загрузок открывает видео папки и перечитывает её при возвращении',
    (tester) async {
      final app = TestApp();

      await app.pumpApp(tester);

      expect(
        tester.getCenter(_inNavigationBar('Плеер')).dy,
        greaterThan(tester.getCenter(_inNavigationBar('Загрузки')).dy),
      );
      expect(
        tester.getCenter(_inNavigationBar('Плеер')).dy,
        lessThan(tester.getCenter(_inNavigationBar('Настройки')).dy),
      );

      await tester.tap(_inNavigationBar('Плеер'));
      await app.settle(tester);

      expect(app.navigationController.state.tab, AppTabModel.player);
      expect(find.byType(PlayerScreen), findsOneWidget);
      expect(find.byType(LibraryVideoCard), findsNWidgets(2));
      expect(app.videoLibraryRepository.syncedFolders, hasLength(1));

      app.videoLibraryRepository.folders[r'C:\Users\user\Downloads']!.add(
        testLibraryVideo('c'),
      );

      await tester.tap(_inNavigationBar('Главная'));
      await app.settle(tester);
      await tester.tap(_inNavigationBar('Плеер'));
      await app.settle(tester);

      expect(find.byType(LibraryVideoCard), findsNWidgets(3));

      /// The player is centered in the whole window, over the navigation bar and the footer
      await tester.tap(find.byTooltip('Смотреть').first);
      await app.settle(tester);

      final dialog = find.byKey(const ValueKey('fake-video-view'));

      expect(dialog, findsOneWidget);
      final box = find
          .ancestor(of: dialog, matching: find.byType(AnimatedContainer))
          .last;

      expect(tester.getCenter(box), const Offset(600, 450));
      expect(tester.getSize(box), const Size(960, 720));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await app.settle(tester);

      expect(dialog, findsNothing);

      await app.close();
    },
  );
}
