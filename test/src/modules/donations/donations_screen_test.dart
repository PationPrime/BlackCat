import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:black_cat/src/app/failure/failure.dart';
import 'package:black_cat/src/app/widgets/widgets.dart';
import 'package:black_cat/src/modules/donations/module.dart';

import '../../support/test_app.dart';
import '../../support/test_localization.dart';

void main() {
  setUpAll(loadTestTranslations);

  testWidgets('площадки поддержки как в rconite: названия, описания и ссылки', (
    tester,
  ) async {
    final app = TestApp();

    await app.pumpPage(
      tester,
      const DonationsScreen(),
      size: const Size(1200, 1400),
    );

    expect(find.text('Поддержать проект'), findsOneWidget);
    expect(find.text('Спасибо, что пользуетесь BlackCat!'), findsOneWidget);
    expect(find.text('СПОСОБЫ ПОДДЕРЖКИ'), findsOneWidget);
    expect(find.text('Спасибо за поддержку!'), findsOneWidget);
    expect(find.byType(DonationPlatformCard), findsNWidgets(3));

    for (final (title, description, link) in [
      (
        'DonationAlerts',
        'Разовый донат с сообщением',
        'donationalerts.com/r/pationprime',
      ),
      ('DonatePay', 'Разовый донат', 'donatepay.ru/don/1453481'),
      ('Boosty', 'Подписка или разовая поддержка', 'boosty.to/pationprime'),
    ]) {
      final card = find.ancestor(
        of: find.text(title),
        matching: find.byType(DonationPlatformCard),
      );

      expect(
        find.descendant(of: card, matching: find.text(description)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text(link)),
        findsOneWidget,
      );
    }

    /// Cards of one row share the height
    final heights = {
      for (final card in find.byType(DonationPlatformCard).evaluate())
        tester.getSize(find.byWidget(card.widget)).height,
    };

    expect(heights, hasLength(1));

    await app.close();
  });

  testWidgets('«Открыть» открывает ссылку, неудача показывается с адресом', (
    tester,
  ) async {
    final app = TestApp();

    await app.pumpPage(
      tester,
      const DonationsScreen(),
      size: const Size(1200, 1400),
    );
    await tester.tap(find.text('Открыть').at(2));
    await app.settle(tester);

    expect(app.urlLauncher.opened, ['https://boosty.to/pationprime']);
    expect(find.byType(AppFailureBanner), findsNothing);

    app.urlLauncher.result = false;

    await tester.tap(find.text('Открыть').first);
    await app.settle(tester);

    expect(
      app.urlLauncher.opened.last,
      'https://www.donationalerts.com/r/pationprime',
    );
    expect(
      find.text(
        'Не удалось открыть ссылку https://www.donationalerts.com/r/pationprime',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Скрыть'));
    await app.settle(tester);

    expect(find.byType(AppFailureBanner), findsNothing);

    await app.close();
  });

  testWidgets('копирование ссылки кладёт её в буфер и ненадолго подтверждает', (
    tester,
  ) async {
    final app = TestApp();
    final copied = <String>[];

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }

        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await app.pumpPage(
      tester,
      const DonationsScreen(),
      size: const Size(1200, 1400),
    );
    await tester.tap(find.byTooltip('Скопировать ссылку').at(1));
    await tester.pump();

    expect(copied, ['https://donatepay.ru/don/1453481']);
    expect(find.text('Ссылка скопирована'), findsOneWidget);
    expect(find.text('donatepay.ru/don/1453481'), findsNothing);

    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Ссылка скопирована'), findsNothing);
    expect(find.text('donatepay.ru/don/1453481'), findsOneWidget);

    await app.close();
  });

  testWidgets('BlackCat на GitHub: звёзды и скачивания последней версии', (
    tester,
  ) async {
    final app = TestApp();

    await app.pumpPage(
      tester,
      const DonationsScreen(),
      size: const Size(1200, 1400),
    );

    final panel = find.byType(ProjectStatsPanel);

    Finder inPanel(String text) =>
        find.descendant(of: panel, matching: find.text(text));

    expect(find.text('BLACKCAT НА GITHUB'), findsOneWidget);
    expect(app.projectStatsRepository.requests, 1);

    for (final (label, value) in [
      ('Звёзды на GitHub', '1'),
      ('Скачиваний для macOS', '3'),
      ('Скачиваний для Windows', '2'),
    ]) {
      final tile = find
          .ancestor(
            of: inPanel(label),
            matching: find.byType(AnimatedContainer),
          )
          .first;

      expect(
        find.descendant(of: tile, matching: find.text(value)),
        findsOneWidget,
        reason: '$value belongs to $label',
      );
    }

    expect(inPanel('Скачивания последней версии v0.1.0'), findsOneWidget);

    /// The stats go before the ways to support
    expect(
      tester.getTopLeft(panel).dy,
      lessThan(tester.getTopLeft(find.text('СПОСОБЫ ПОДДЕРЖКИ')).dy),
    );

    await app.close();
  });

  testWidgets('счётчик звёзд открывает репозиторий на GitHub', (tester) async {
    final app = TestApp();

    await app.pumpPage(
      tester,
      const DonationsScreen(),
      size: const Size(1200, 1400),
    );

    expect(find.byTooltip('Открыть репозиторий на GitHub'), findsOneWidget);

    await tester.tap(find.text('Звёзды на GitHub'));
    await app.settle(tester);

    expect(app.urlLauncher.opened, ['https://github.com/PationPrime/BlackCat']);

    /// Downloads are numbers only
    await tester.tap(find.text('Скачиваний для macOS'));
    await app.settle(tester);

    expect(app.urlLauncher.opened, hasLength(1));

    await app.close();
  });

  testWidgets('GitHub не ответил — вместо чисел прочерки', (tester) async {
    final app = TestApp();

    app.projectStatsRepository.result = (
      failure: const UnknownFailure(message: 'offline'),
      data: null,
    );

    await app.pumpPage(
      tester,
      const DonationsScreen(),
      size: const Size(1200, 1400),
    );

    expect(
      find.descendant(
        of: find.byType(ProjectStatsPanel),
        matching: find.text('—'),
      ),
      findsNWidgets(3),
    );
    expect(find.textContaining('Скачивания последней версии'), findsNothing);
    expect(find.byType(AppFailureBanner), findsNothing);

    await app.close();
  });

  testWidgets(
    'в узкой колонке карточки идут друг под другом без переполнения',
    (tester) async {
      final app = TestApp();

      await app.pumpPage(
        tester,
        const DonationsScreen(),
        size: const Size(420, 2600),
      );

      final cards = find.byType(DonationPlatformCard);
      final stats = find.descendant(
        of: find.byType(ProjectStatsPanel),
        matching: find.byType(Tooltip),
      );

      /// The GitHub numbers too
      expect(
        tester.getTopLeft(stats).dy,
        lessThan(tester.getTopLeft(find.text('Скачиваний для macOS')).dy),
      );
      expect(
        tester.getTopLeft(cards.at(0)).dy,
        lessThan(tester.getTopLeft(cards.at(1)).dy),
      );
      expect(
        tester.getTopLeft(cards.at(1)).dy,
        lessThan(tester.getTopLeft(cards.at(2)).dy),
      );
      expect(tester.takeException(), isNull);

      await app.close();
    },
  );
}
