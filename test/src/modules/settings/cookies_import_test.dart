import 'package:flutter_test/flutter_test.dart';
import 'package:black_cat/src/app/errors/errors.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/shared_controllers/shared_controllers.dart';
import 'package:black_cat/src/modules/settings/module.dart';

import '../../support/test_app.dart';
import '../../support/test_localization.dart';

void main() {
  setUpAll(loadTestTranslations);

  testWidgets(
    'карточка cookies: инструкция, ссылка на FAQ, ошибки файла и ссылки',
    (tester) async {
      final app = TestApp();

      await app.pumpPage(tester, const SettingsScreen());

      expect(find.text('Настройки'), findsOneWidget);
      expect(find.text('Cookies YouTube'), findsOneWidget);
      expect(find.text('Как получить cookies.txt'), findsOneWidget);
      expect(find.textContaining('приватное (инкогнито) окно'), findsOneWidget);
      expect(find.textContaining('не передавайте его другим'), findsOneWidget);
      expect(find.text('Файл не выбран'), findsOneWidget);
      expect(
        tester.widget<CookiesCard>(find.byType(CookiesCard)).highlighted,
        isFalse,
      );

      await tester.tap(find.text('Подробная инструкция в FAQ yt-dlp'));
      await app.settle(tester);

      expect(app.urlLauncher.opened, [
        'https://github.com/yt-dlp/yt-dlp/wiki/FAQ#how-do-i-pass-cookies-to-yt-dlp',
      ]);

      app.authenticationRepository.importResult = (
        failure: const AuthenticationFailure(
          code: 'cookies_json',
          message:
              'Cookies сохранены в формате JSON. Экспортируйте их в формате Netscape (cookies.txt).',
        ),
        data: null,
      );

      await tester.tap(find.text('Выбрать cookies.txt…'));
      await app.settle(tester);

      final card = find.byType(CookiesCard);

      expect(
        find.descendant(
          of: card,
          matching: find.textContaining('в формате JSON'),
        ),
        findsOneWidget,
      );
      expect(app.authorizationController.state.isAuthorized, isFalse);

      /// The downloads page does not repeat the settings error
      expect(app.queueController.state.failure, isNull);

      await tester.tap(
        find.descendant(of: card, matching: find.text('Скрыть')),
      );
      await app.settle(tester);

      expect(find.textContaining('в формате JSON'), findsNothing);

      app.urlLauncher.result = false;

      await tester.tap(find.text('Подробная инструкция в FAQ yt-dlp'));
      await app.settle(tester);

      expect(find.textContaining('Не удалось открыть ссылку'), findsOneWidget);

      await app.close();
    },
  );

  testWidgets(
    'импорт из обычных настроек остаётся на странице; удаление cookies выходит из аккаунта',
    (tester) async {
      final app = TestApp();

      app.authenticationRepository.restoreResult = (
        failure: null,
        data: const AccountSessionModel.signInWindow(),
      );
      app.navigationController.selectTab(AppTabModel.settings);

      await app.pumpPage(tester, const SettingsScreen());

      expect(find.textContaining('Импорт cookies заменит его'), findsOneWidget);
      expect(find.text('Удалить cookies'), findsNothing);

      app.authenticationRepository.importResult = (
        failure: null,
        data: AccountSessionModel.cookiesFile(
          cookiesFilePath: r'C:\Users\user\Downloads\cookies.txt',
          importedAt: DateTime(2026, 9, 16, 14, 30),
        ),
      );

      await tester.tap(find.text('Выбрать cookies.txt…'));
      await app.settle(tester);

      expect(app.navigationController.state.tab, AppTabModel.settings);
      expect(
        find.text('Cookies импортированы: вход в YouTube выполнен.'),
        findsOneWidget,
      );
      expect(find.text(r'C:\Users\user\Downloads\cookies.txt'), findsOneWidget);
      expect(find.text('Используется'), findsOneWidget);

      await tester.tap(find.text('Удалить cookies'));
      await app.settle(tester);

      expect(app.authenticationRepository.signOutCalls, 1);
      expect(app.authorizationController.state.isAuthorized, isFalse);
      expect(find.text('Файл не выбран'), findsOneWidget);

      await app.close();
    },
  );

  testWidgets(
    'запрос импорта подсвечивает карточку и после импорта возвращает на запросившую страницу',
    (tester) async {
      final app = TestApp();

      await app.pumpPage(tester, const SettingsScreen());

      app.navigationController.openCookiesImport(
        returnTab: AppTabModel.downloads,
      );
      await app.settle(tester);

      expect(
        tester.widget<CookiesCard>(find.byType(CookiesCard)).highlighted,
        isTrue,
      );
      expect(
        find.text('Как получить cookies.txt').hitTestable(),
        findsOneWidget,
      );

      /// Closing the picker keeps the request
      await tester.tap(find.text('Выбрать cookies.txt…'));
      await app.settle(tester);

      expect(app.navigationController.state.tab, AppTabModel.settings);

      app.authenticationRepository.importResult = (
        failure: null,
        data: AccountSessionModel.cookiesFile(
          cookiesFilePath: r'C:\cookies.txt',
          importedAt: DateTime(2026, 9, 16),
        ),
      );

      await tester.tap(find.text('Выбрать cookies.txt…'));
      await app.settle(tester);

      expect(
        app.navigationController.state,
        const AppNavigationState(tab: AppTabModel.downloads),
      );
      expect(
        tester.widget<CookiesCard>(find.byType(CookiesCard)).highlighted,
        isFalse,
      );

      await app.close();
    },
  );
}
