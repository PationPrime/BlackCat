import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/src/app/design_system/design_system.dart';
import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/repositories/repositories.dart';
import 'package:youtube_downloader/src/app/router/app_router.dart';
import 'package:youtube_downloader/src/app/services/services.dart';
import 'package:youtube_downloader/src/app/shared_controllers/shared_controllers.dart';
import 'package:youtube_downloader/src/app/widgets/widgets.dart';
import 'package:youtube_downloader/src/modules/downloader/module.dart';
import 'package:youtube_downloader/src/modules/settings/module.dart';

import '../../support/fake_repositories.dart';
import '../../support/test_localization.dart';

const _url = 'https://youtu.be/kgA8JPY2lIA';

const _signInFailure = VideoFailure(
  code: 'bot_check',
  message: 'YouTube просит подтвердить, что вы не бот.',
  needsSignIn: true,
);

final _importedSession = AccountSessionModel.cookiesFile(
  cookiesFilePath: r'C:\Users\user\Downloads\cookies.txt',
  importedAt: DateTime(2026, 9, 16, 14, 30),
);

/// The main screen and the settings in one stack, like in the app
class _TestRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(path: '/', page: DownloaderRoute.page, initial: true),
    AutoRoute(path: '/settings', page: SettingsRoute.page),
  ];
}

final class _FakeUrlLauncher implements UrlLauncherService {
  final opened = <String>[];
  var result = true;

  @override
  Future<bool> openUrl(String url) async {
    opened.add(url);

    return result;
  }
}

final class _App {
  final videoRepository = FakeVideoRepository(
    infoResults: [(failure: _signInFailure, data: null), (failure: null, data: testVideoInfo)],
  );
  final authenticationRepository = FakeAuthenticationRepository();
  final urlLauncher = _FakeUrlLauncher();
  final router = _TestRouter();
  late final authorizationController = AuthorizationController(authenticationRepository: authenticationRepository);
  late final queueController = DownloadQueueController(
    downloadQueueRepository: FakeDownloadQueueRepository(),
    videoRepository: videoRepository,
    ytDlpVideoRepository: FakeYtDlpVideoRepository(),
    settingsRepository: FakeSettingsRepository(),
    authorizationController: authorizationController,
  );

  /// yt-dlp is missing: the built-in downloader searches
  final dependenciesController = DependenciesController(
    dependenciesRepository: FakeDependenciesRepository(setupResults: [(failure: null, data: const YtDlpSetupModel())]),
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
          RepositoryProvider<UrlLauncherService>.value(value: urlLauncher),
          RepositoryProvider<VideoRepositoryInterface>.value(value: videoRepository),
          RepositoryProvider<YtDlpVideoRepositoryInterface>.value(value: FakeYtDlpVideoRepository()),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<AuthorizationController>.value(value: authorizationController),
            BlocProvider<DownloadQueueController>.value(value: queueController),
            BlocProvider<DependenciesController>.value(value: dependenciesController),
            BlocProvider<SettingsController>(
              create: (_) => SettingsController(settingsRepository: FakeSettingsRepository())..loadSettings(),
            ),
          ],
          child: MaterialApp.router(theme: AppThemeData.darkTheme, routerConfig: router.config()),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> close() async {
    await queueController.close();
    await dependenciesController.close();
  }
}

void main() {
  setUpAll(loadTestTranslations);

  testWidgets('«Импортировать cookies.txt» ведёт в настройки, после импорта поиск повторяется', (tester) async {
    final app = _App();

    await app.pump(tester);
    await tester.tap(find.text('Добавить видео'));
    await app.settle(tester);
    await tester.enterText(find.byType(TextField), _url);
    await tester.tap(find.text('Найти'));
    await app.settle(tester);

    await tester.tap(find.text('Импортировать cookies.txt'));
    await app.settle(tester);

    /// The dialog is closed, the settings show the highlighted cookies card
    expect(find.byType(AddVideoDialog), findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(tester.widget<CookiesCard>(find.byType(CookiesCard)).highlighted, isTrue);
    expect(find.text('Cookies YouTube'), findsOneWidget);
    expect(find.text('Как получить cookies.txt'), findsOneWidget);
    expect(find.text('Файл не выбран'), findsOneWidget);
    expect(find.text('Cookies YouTube').hitTestable(), findsOneWidget);

    await tester.tap(find.text('Подробная инструкция в FAQ yt-dlp'));
    await app.settle(tester);

    expect(app.urlLauncher.opened, ['https://github.com/yt-dlp/yt-dlp/wiki/FAQ#how-do-i-pass-cookies-to-yt-dlp']);

    app.authenticationRepository.importResult = (failure: null, data: _importedSession);

    await tester.tap(find.text('Выбрать cookies.txt…'));
    await app.settle(tester);

    expect(app.authenticationRepository.importCalls, 1);
    expect(find.text('Cookies импортированы: вход в YouTube выполнен.'), findsOneWidget);
    expect(find.text(r'C:\Users\user\Downloads\cookies.txt'), findsOneWidget);
    expect(find.text('Используется'), findsOneWidget);
    expect(find.text('Удалить cookies'), findsOneWidget);

    await tester.tap(find.byTooltip('Назад'));
    await app.settle(tester);

    /// Back on the main screen the dialog opens again and repeats the search
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.byType(AddVideoDialog), findsOneWidget);
    expect(app.videoRepository.requestedUrls, [_url, _url]);
    expect(find.text('Обзор'), findsOneWidget);
    expect(find.byType(AppFailureBanner), findsNothing);

    await tester.tap(find.text('Отмена'));
    await app.settle(tester);
    await app.close();
  });

  testWidgets('без импорта диалог открывается снова с той же ссылкой, но без поиска', (tester) async {
    final app = _App();

    await app.pump(tester);
    await tester.tap(find.text('Добавить видео'));
    await app.settle(tester);
    await tester.enterText(find.byType(TextField), _url);
    await tester.tap(find.text('Найти'));
    await app.settle(tester);
    await tester.tap(find.text('Импортировать cookies.txt'));
    await app.settle(tester);

    /// The picker was closed
    await tester.tap(find.text('Выбрать cookies.txt…'));
    await app.settle(tester);

    expect(find.text('Cookies импортированы: вход в YouTube выполнен.'), findsNothing);

    await tester.tap(find.byTooltip('Назад'));
    await app.settle(tester);

    expect(find.byType(AddVideoDialog), findsOneWidget);
    expect(find.widgetWithText(TextField, _url), findsOneWidget);
    expect(app.videoRepository.requestedUrls, [_url]);

    await tester.tap(find.text('Отмена'));
    await app.settle(tester);
    await app.close();
  });

  testWidgets('ошибка файла и неоткрытая ссылка показываются в карточке cookies', (tester) async {
    final app = _App();

    await app.pump(tester);
    /// The route completes only when it is closed
    app.router.push(SettingsRoute()).ignore();
    await app.settle(tester);

    expect(tester.widget<CookiesCard>(find.byType(CookiesCard)).highlighted, isFalse);

    app.authenticationRepository.importResult = (
      failure: const AuthenticationFailure(
        code: 'cookies_json',
        message: 'Cookies сохранены в формате JSON. Экспортируйте их в формате Netscape (cookies.txt).',
      ),
      data: null,
    );

    await tester.tap(find.text('Выбрать cookies.txt…'));
    await app.settle(tester);

    final card = find.byType(CookiesCard);

    expect(
      find.descendant(of: card, matching: find.textContaining('в формате JSON')),
      findsOneWidget,
    );
    expect(app.authorizationController.state.isAuthorized, isFalse);

    /// The main screen does not repeat the settings error
    expect(app.queueController.state.failure, isNull);

    await tester.tap(find.descendant(of: card, matching: find.text('Скрыть')));
    await app.settle(tester);

    expect(find.textContaining('в формате JSON'), findsNothing);

    app.urlLauncher.result = false;

    await tester.tap(find.text('Подробная инструкция в FAQ yt-dlp'));
    await app.settle(tester);

    expect(find.textContaining('Не удалось открыть ссылку'), findsOneWidget);

    await app.close();
  });

  testWidgets('вход через окно приложения: карточка предупреждает о замене, удалить нечего', (tester) async {
    final app = _App();

    app.authenticationRepository.restoreResult = (failure: null, data: const AccountSessionModel.signInWindow());

    await app.pump(tester);
    /// The route completes only when it is closed
    app.router.push(SettingsRoute()).ignore();
    await app.settle(tester);

    expect(find.textContaining('Импорт cookies заменит его'), findsOneWidget);
    expect(find.text('Удалить cookies'), findsNothing);

    app.authenticationRepository.importResult = (failure: null, data: _importedSession);

    await tester.tap(find.text('Выбрать cookies.txt…'));
    await app.settle(tester);
    await tester.tap(find.text('Удалить cookies'));
    await app.settle(tester);

    expect(app.authenticationRepository.signOutCalls, 1);
    expect(app.authorizationController.state.isAuthorized, isFalse);
    expect(find.text('Файл не выбран'), findsOneWidget);

    await app.close();
  });
}
