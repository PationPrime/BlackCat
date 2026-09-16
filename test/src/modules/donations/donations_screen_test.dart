import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/src/app/widgets/widgets.dart';
import 'package:youtube_downloader/src/modules/donations/module.dart';

import '../../support/test_app.dart';
import '../../support/test_localization.dart';

void main() {
  setUpAll(loadTestTranslations);

  testWidgets('площадки поддержки как в rconite: названия, описания и ссылки', (tester) async {
    final app = TestApp();

    await app.pumpPage(tester, const DonationsScreen(), size: const Size(1200, 1400));

    expect(find.text('Поддержать проект'), findsOneWidget);
    expect(find.text('Спасибо, что пользуетесь YT Download!'), findsOneWidget);
    expect(find.text('СПОСОБЫ ПОДДЕРЖКИ'), findsOneWidget);
    expect(find.text('Спасибо за поддержку!'), findsOneWidget);
    expect(find.byType(DonationPlatformCard), findsNWidgets(3));

    for (final (title, description, link) in [
      ('DonationAlerts', 'Разовый донат с сообщением', 'donationalerts.com/r/pationprime'),
      ('DonatePay', 'Разовый донат', 'donatepay.ru/don/1453481'),
      ('Boosty', 'Подписка или разовая поддержка', 'boosty.to/pationprime'),
    ]) {
      final card = find.ancestor(of: find.text(title), matching: find.byType(DonationPlatformCard));

      expect(find.descendant(of: card, matching: find.text(description)), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(link)), findsOneWidget);
    }

    /// Cards of one row share the height
    final heights = {
      for (final card in find.byType(DonationPlatformCard).evaluate()) tester.getSize(find.byWidget(card.widget)).height,
    };

    expect(heights, hasLength(1));

    await app.close();
  });

  testWidgets('«Открыть» открывает ссылку, неудача показывается с адресом', (tester) async {
    final app = TestApp();

    await app.pumpPage(tester, const DonationsScreen(), size: const Size(1200, 1400));
    await tester.tap(find.text('Открыть').at(2));
    await app.settle(tester);

    expect(app.urlLauncher.opened, ['https://boosty.to/pationprime']);
    expect(find.byType(AppFailureBanner), findsNothing);

    app.urlLauncher.result = false;

    await tester.tap(find.text('Открыть').first);
    await app.settle(tester);

    expect(app.urlLauncher.opened.last, 'https://www.donationalerts.com/r/pationprime');
    expect(
      find.text('Не удалось открыть ссылку https://www.donationalerts.com/r/pationprime'),
      findsOneWidget,
    );

    await tester.tap(find.text('Скрыть'));
    await app.settle(tester);

    expect(find.byType(AppFailureBanner), findsNothing);

    await app.close();
  });

  testWidgets('копирование ссылки кладёт её в буфер и ненадолго подтверждает', (tester) async {
    final app = TestApp();
    final copied = <String>[];

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }

      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await app.pumpPage(tester, const DonationsScreen(), size: const Size(1200, 1400));
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

  testWidgets('в узкой колонке карточки идут друг под другом без переполнения', (tester) async {
    final app = TestApp();

    await app.pumpPage(tester, const DonationsScreen(), size: const Size(420, 2600));

    final cards = find.byType(DonationPlatformCard);

    expect(tester.getTopLeft(cards.at(0)).dy, lessThan(tester.getTopLeft(cards.at(1)).dy));
    expect(tester.getTopLeft(cards.at(1)).dy, lessThan(tester.getTopLeft(cards.at(2)).dy));
    expect(tester.takeException(), isNull);

    await app.close();
  });
}
