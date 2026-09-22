import 'package:flutter_test/flutter_test.dart';
import 'package:black_cat/src/app/errors/errors.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/widgets/widgets.dart';
import 'package:black_cat/src/modules/settings/module.dart';

import '../../support/test_app.dart';
import '../../support/test_localization.dart';

void main() {
  setUpAll(loadTestTranslations);

  testWidgets('в настройках видна версия приложения с номером сборки', (
    tester,
  ) async {
    final app = TestApp();

    await app.pumpPage(tester, const SettingsScreen());

    final card = find.byType(AboutCard);

    expect(
      find.descendant(of: card, matching: find.text('О приложении')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('BlackCat')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.byType(AppIconLogo)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Версия 0.2.0 (сборка 1)')),
      findsOneWidget,
    );

    /// The last card of the page
    expect(
      tester.getTopLeft(card).dy,
      greaterThan(tester.getTopLeft(find.byType(CookiesCard)).dy),
    );

    await app.close();
  });

  testWidgets('сборка без номера — только версия', (tester) async {
    final app = TestApp();

    app.settingsRepository.appVersionResult = (
      failure: null,
      data: const AppVersionModel(version: '0.2.0'),
    );

    await app.pumpPage(tester, const SettingsScreen());

    expect(find.text('Версия 0.2.0'), findsOneWidget);

    await app.close();
  });

  testWidgets('версия не прочиталась — карточка без неё и без ошибки', (
    tester,
  ) async {
    final app = TestApp();

    app.settingsRepository.appVersionResult = (
      failure: const SettingsFailure(message: 'no version'),
      data: null,
    );

    await app.pumpPage(tester, const SettingsScreen());

    expect(find.byType(AboutCard), findsOneWidget);
    expect(find.textContaining('Версия'), findsNothing);
    expect(find.byType(AppFailureBanner), findsNothing);

    await app.close();
  });
}
