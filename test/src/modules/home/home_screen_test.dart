import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:black_cat/src/app/errors/errors.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/widgets/widgets.dart';
import 'package:black_cat/src/modules/dependencies/module.dart';
import 'package:black_cat/src/modules/home/module.dart';

import '../../support/fake_repositories.dart';
import '../../support/test_app.dart';
import '../../support/test_localization.dart';

/// The page has a second link field, for downloading any file: the search
/// is the one in the search form
final _searchField = find.descendant(
  of: find.byType(UrlSearchForm),
  matching: find.byType(TextField),
);

const _url = 'https://youtu.be/kgA8JPY2lIA';
const _otherUrl = 'https://youtu.be/otherVideo1';
const _rutubeUrl = 'https://rutube.ru/shorts/7fe803e5db2951c0a6097232efc4a439/';
const _tiktokUrl =
    'https://www.tiktok.com/@bmw/video/7664657841843719457?is_from_webapp=1';

const _signInFailure = VideoFailure(
  code: 'bot_check',
  message: 'YouTube просит подтвердить, что вы не бот.',
  needsSignIn: true,
);

/// Texts inside [finder] in the order they are drawn
List<String?> _textsOf(WidgetTester tester, Finder finder) => [
  for (final text in tester.widgetList<Text>(
    find.descendant(of: finder, matching: find.byType(Text)),
  ))
    text.data,
];

void main() {
  setUpAll(loadTestTranslations);

  testWidgets('поиск по Enter в поле ссылки: обычный и цифровой Enter', (
    tester,
  ) async {
    final app = TestApp(
      ytDlpVideoRepository: FakeYtDlpVideoRepository(
        infoResults: [
          (failure: null, data: testVideoInfo),
          (failure: null, data: testVideoInfo),
        ],
      ),
    );

    await app.pumpPage(tester, const YouTubeDownloadScreen());
    await app.dependenciesController.check();

    expect(find.text('YouTube'), findsOneWidget);

    await tester.enterText(_searchField, _url);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await app.settle(tester);

    expect(app.ytDlpVideoRepository.requestedUrls, [_url]);
    expect(find.byType(VideoCard), findsOneWidget);

    await tester.enterText(_searchField, _otherUrl);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    await app.settle(tester);

    expect(app.ytDlpVideoRepository.requestedUrls, [_url, _otherUrl]);

    await app.close();
  });

  testWidgets('пустая ссылка по Enter не ищется', (tester) async {
    final app = TestApp();

    await app.pumpPage(tester, const YouTubeDownloadScreen());
    await tester.enterText(_searchField, '   ');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await app.settle(tester);

    expect(app.ytDlpVideoRepository.requestedUrls, isEmpty);
    expect(app.videoRepository.requestedUrls, isEmpty);

    await app.close();
  });

  testWidgets(
    'найденное видео добавляется в загрузки: форма очищается, видно подтверждение',
    (tester) async {
      final app = TestApp(
        ytDlpVideoRepository: FakeYtDlpVideoRepository(
          infoResults: List.filled(3, (failure: null, data: testVideoInfo)),
        ),
      );

      await app.pumpPage(tester, const YouTubeDownloadScreen());
      await app.dependenciesController.check();
      await tester.enterText(_searchField, _url);
      await tester.tap(find.text('Найти'));
      await app.settle(tester);

      expect(find.text('Обзор'), findsOneWidget);
      expect(find.text('Скачать'), findsOneWidget);

      await tester.tap(find.text('Скачать'));
      await app.settle(tester);

      expect(app.queueController.state.activeTask?.video.title, 'Обзор');
      expect(app.queueController.state.activeTask?.quality.id, '1080');
      expect(
        app.queueController.state.activeTask?.engine,
        DownloadEngineModel.ytDlp,
      );
      expect(find.byType(VideoCard), findsNothing);
      expect(tester.widget<TextField>(_searchField).controller?.text, isEmpty);
      expect(find.text('«Обзор» добавлено в загрузки.'), findsOneWidget);

      /// The next video goes to the queue
      await tester.enterText(_searchField, _url);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await app.settle(tester);

      expect(find.text('«Обзор» добавлено в загрузки.'), findsNothing);
      expect(find.text('Добавить в очередь'), findsOneWidget);

      await tester.tap(find.text('Очистить'));
      await app.settle(tester);

      expect(find.byType(VideoCard), findsNothing);

      await tester.enterText(_searchField, _url);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await app.settle(tester);
      await tester.tap(find.text('Добавить в очередь'));
      await app.settle(tester);

      expect(app.queueController.state.queue, hasLength(1));

      await tester.tap(find.text('Открыть загрузки'));
      await app.settle(tester);

      expect(app.navigationController.state.tab, AppTabModel.downloads);

      await app.close();
    },
  );

  testWidgets(
    'без yt-dlp ищет встроенный загрузчик, «Установить» открывает установку',
    (tester) async {
      final app = TestApp(setup: const YtDlpSetupModel());

      await app.pumpPage(tester, const YouTubeDownloadScreen());
      await app.dependenciesController.check();
      await app.settle(tester);

      expect(
        find.text(
          'yt-dlp не установлен: видео скачается встроенным загрузчиком.',
        ),
        findsOneWidget,
      );

      await tester.enterText(_searchField, _url);
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

      expect(
        find.text('Поиск может занимать несколько секунд.'),
        findsOneWidget,
      );

      await app.close();
    },
  );

  testWidgets(
    'ошибка входа: сначала cookies, вход через Google — только после предупреждения',
    (tester) async {
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

      await app.pumpPage(tester, const YouTubeDownloadScreen());
      await tester.enterText(_searchField, _url);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await app.settle(tester);

      final banner = find.byType(AppFailureBanner);

      expect(
        find.descendant(
          of: banner,
          matching: find.text('YouTube просит подтвердить, что вы не бот.'),
        ),
        findsOneWidget,
      );
      expect(
        _textsOf(tester, banner),
        containsAllInOrder(['Добавить cookies', 'Войти через Google']),
      );

      /// The Google window opens only after the warning; cancelling it
      /// leaves everything as it was
      await tester.tap(
        find.descendant(of: banner, matching: find.text('Войти через Google')),
      );
      await app.settle(tester);

      expect(
        find.text('Вход через Google — только в крайнем случае'),
        findsOneWidget,
      );
      expect(find.textContaining('Google Cloud Console'), findsOneWidget);

      await tester.tap(find.text('Отмена'));
      await app.settle(tester);

      expect(app.authenticationRepository.signInCalls, 0);

      /// Insisting opens the window, and the search repeats right away
      await tester.tap(
        find.descendant(of: banner, matching: find.text('Войти через Google')),
      );
      await app.settle(tester);
      await tester.tap(find.text('Всё равно войти через Google'));
      await app.settle(tester);

      expect(app.authenticationRepository.signInCalls, 1);
      expect(app.videoRepository.requestedUrls, [_url, _url]);
      expect(
        find.descendant(
          of: banner,
          matching: find.text('Обновить вход через Google'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(of: banner, matching: find.text('Добавить cookies')),
      );
      await app.settle(tester);

      expect(app.navigationController.state.tab, AppTabModel.settings);
      expect(
        app.navigationController.state.cookiesImport?.returnTab,
        AppTabModel.home,
      );

      app.authenticationRepository.importResult = (
        failure: null,
        data: AccountSessionModel.cookiesFile(
          cookiesFilePath: r'C:\cookies.txt',
          importedAt: DateTime(2026, 9, 16),
        ),
      );
      await app.authorizationController.importCookies();
      await app.settle(tester);

      expect(app.videoRepository.requestedUrls, [_url, _url, _url]);
      expect(find.byType(AppFailureBanner), findsNothing);
      expect(find.text('Обзор'), findsOneWidget);

      await app.close();
    },
  );

  testWidgets(
    'заголовок главной: cookies — главная кнопка, вход через Google — ссылка с предупреждением',
    (tester) async {
      final app = TestApp();

      await app.pumpPage(tester, const YouTubeDownloadScreen());

      final header = find.byType(AppPageHeader);
      final recommendation = find.byType(CookiesRecommendation);

      expect(
        find.descendant(of: header, matching: find.byType(AppSecondaryButton)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: header, matching: find.text('Добавить cookies')),
        findsOneWidget,
      );
      expect(recommendation, findsOneWidget);
      expect(
        find.descendant(
          of: recommendation,
          matching: find.text('Войдите с помощью cookies'),
        ),
        findsOneWidget,
      );

      /// The warning itself offers cookies first
      await tester.tap(
        find.descendant(of: header, matching: find.text('Войти через Google')),
      );
      await app.settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Добавить cookies'),
        ),
      );
      await app.settle(tester);

      expect(app.authenticationRepository.signInCalls, 0);
      expect(app.navigationController.state.tab, AppTabModel.settings);

      await tester.tap(
        find.descendant(of: header, matching: find.text('Войти через Google')),
      );
      await app.settle(tester);
      await tester.tap(find.text('Всё равно войти через Google'));
      await app.settle(tester);

      expect(app.authenticationRepository.signInCalls, 1);
      expect(
        find.descendant(of: header, matching: find.text('Вход через Google')),
        findsOneWidget,
      );

      /// Signed in through the window: the page offers to replace it
      expect(
        find.descendant(
          of: recommendation,
          matching: find.text('Заменить на cookies'),
        ),
        findsOneWidget,
      );

      await app.addTask(tester, 'a');

      expect(
        tester
            .widget<AppLinkButton>(find.widgetWithText(AppLinkButton, 'Выйти'))
            .onPressed,
        isNull,
      );

      app.videoRepository.downloads.single.succeed(r'C:\Downloads\a.mp4');
      await app.settle(tester);

      await tester.tap(
        find.descendant(of: header, matching: find.text('Выйти')),
      );
      await app.settle(tester);

      expect(app.authenticationRepository.signOutCalls, 1);
      expect(
        find.descendant(of: header, matching: find.text('Добавить cookies')),
        findsOneWidget,
      );

      /// With cookies the header offers to update them, the advice is gone
      app.authenticationRepository.importResult = (
        failure: null,
        data: AccountSessionModel.cookiesFile(
          cookiesFilePath: r'C:\cookies.txt',
          importedAt: DateTime(2026, 9, 16),
        ),
      );
      await app.authorizationController.importCookies();
      await app.settle(tester);

      expect(
        find.descendant(of: header, matching: find.text('Cookies подключены')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: header, matching: find.text('Обновить')),
        findsOneWidget,
      );
      expect(recommendation, findsNothing);

      await app.close();
    },
  );

  testWidgets(
    'вкладка RuTube ищет видео и шортсы RuTube, ссылки других сайтов не принимает',
    (tester) async {
      final app = TestApp(
        ytDlpVideoRepository: FakeYtDlpVideoRepository(
          infoResults: [(failure: null, data: testVideoInfo)],
        ),
      );

      await app.pumpPage(tester, const RuTubeDownloadScreen());
      await app.dependenciesController.check();

      expect(find.text('RuTube'), findsOneWidget);

      await tester.enterText(_searchField, _url);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await app.settle(tester);

      expect(find.text('Это не ссылка на видео RuTube.'), findsOneWidget);
      expect(app.ytDlpVideoRepository.requestedUrls, isEmpty);

      await tester.enterText(_searchField, _rutubeUrl);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await app.settle(tester);

      expect(app.ytDlpVideoRepository.requestedUrls, [_rutubeUrl]);
      expect(find.byType(VideoCard), findsOneWidget);
      expect(find.text('Это не ссылка на видео RuTube.'), findsNothing);

      await app.close();
    },
  );

  testWidgets(
    'вкладка TikTok ищет видео TikTok, ссылки других сайтов не принимает',
    (tester) async {
      final app = TestApp(
        ytDlpVideoRepository: FakeYtDlpVideoRepository(
          infoResults: [(failure: null, data: testVideoInfo)],
        ),
      );

      await app.pumpPage(tester, const TikTokDownloadScreen());
      await app.dependenciesController.check();

      expect(find.text('TikTok'), findsOneWidget);
      expect(
        find.text('https://www.tiktok.com/@user/video/...'),
        findsOneWidget,
      );

      await tester.enterText(_searchField, _rutubeUrl);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await app.settle(tester);

      expect(find.text('Это не ссылка на видео TikTok.'), findsOneWidget);
      expect(app.ytDlpVideoRepository.requestedUrls, isEmpty);

      await tester.enterText(_searchField, _tiktokUrl);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await app.settle(tester);

      expect(app.ytDlpVideoRepository.requestedUrls, [_tiktokUrl]);
      expect(find.byType(VideoCard), findsOneWidget);
      expect(find.text('Это не ссылка на видео TikTok.'), findsNothing);

      await app.close();
    },
  );

  testWidgets('вкладка YouTube не принимает ссылки RuTube', (tester) async {
    final app = TestApp();

    await app.pumpPage(tester, const YouTubeDownloadScreen());
    await tester.enterText(_searchField, _rutubeUrl);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await app.settle(tester);

    expect(find.text('Это не ссылка на YouTube-видео.'), findsOneWidget);
    expect(app.ytDlpVideoRepository.requestedUrls, isEmpty);
    expect(app.videoRepository.requestedUrls, isEmpty);

    await app.close();
  });
}
