import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:black_cat/src/app/widgets/widgets.dart';
import 'package:black_cat/src/modules/home/module.dart';

import '../../support/test_app.dart';
import '../../support/test_localization.dart';

void main() {
  setUpAll(loadTestTranslations);

  Future<void> pumpForm(
    WidgetTester tester,
    TestApp app, {
    required bool loading,
    List<String>? submitted,
  }) => app.pumpPage(
    tester,
    Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: UrlSearchForm(
          controller: TextEditingController(text: 'https://youtu.be/a'),
          loading: loading,
          enabled: !loading,
          onSubmitted: submitted?.add,
        ),
      ),
    ),
  );

  testWidgets(
    'во время поиска кнопка крутит индикатор со скруглёнными краями вместо текста',
    (tester) async {
      final app = TestApp();

      await pumpForm(tester, app, loading: false);

      final button = find.byType(AppPrimaryButton);
      final idleSize = tester.getSize(button);

      expect(find.text('Найти'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      final submitted = <String>[];

      await pumpForm(tester, app, loading: true, submitted: submitted);
      await tester.pump();

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );

      expect(indicator.strokeCap, StrokeCap.round);
      expect(indicator.semanticsLabel, 'Ищем…');
      expect(find.text('Ищем…'), findsNothing);

      /// The button keeps its width: the row does not jump
      expect(tester.getSize(button), idleSize);

      /// A busy button is not dimmed like a disabled one
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: find.byType(CircularProgressIndicator),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        1,
      );

      await tester.tap(button);

      expect(submitted, isEmpty);

      await app.close();
    },
  );
}
