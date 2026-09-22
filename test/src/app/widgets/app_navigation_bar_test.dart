import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peeky_cat/src/app/design_system/design_system.dart';
import 'package:peeky_cat/src/app/widgets/widgets.dart';
import 'package:peeky_cat/src/generated/assets/assets.gen.dart';

final _items = [
  AppNavigationBarItemData(
    title: 'Главная',
    svgPictureFilePath: Assets.icons.iconNavbarHome.path,
  ),
  AppNavigationBarItemData(
    title: 'Загрузки',
    svgPictureFilePath: Assets.icons.iconNavbarDownload.path,
    badge: 3,
  ),
  AppNavigationBarItemData(
    title: 'Настройки',
    svgPictureFilePath: Assets.icons.iconNavbarSettings.path,
  ),
];

final class _Bar {
  var selectedIndex = 0;
  final selected = <int>[];

  Future<void> pump(WidgetTester tester, {bool compact = false}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppThemeData.darkTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  height: 400,
                  child: AppNavigationBar(
                    compact: compact,
                    items: _items,
                    selectedIndex: selectedIndex,
                    onSelected: (index) {
                      selected.add(index);
                      setState(() => selectedIndex = index);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Top of the selection pill inside the button list
double _pillTop(WidgetTester tester) => tester
    .widget<Positioned>(
      find
          .descendant(
            of: find.byType(AppNavigationBar),
            matching: find.byType(Positioned),
          )
          .first,
    )
    .top!;

Color? _titleColor(WidgetTester tester, String title) =>
    tester.widget<Text>(find.text(title)).style?.color;

/// The button icon: an svg file of its own for every button
Finder _icon(String assetPath) => find.byWidgetPredicate(
  (widget) =>
      widget is SvgPicture &&
      widget.bytesLoader is SvgAssetLoader &&
      (widget.bytesLoader as SvgAssetLoader).assetName == assetPath,
);

void main() {
  testWidgets(
    'таблетка выбора плавно переезжает к нажатой кнопке, цвета меняются по пути',
    (tester) async {
      final bar = _Bar();

      await bar.pump(tester);

      final accentText = AppThemeData.darkTheme
          .extension<AppThemeColors>()!
          .onAccent;

      expect(_pillTop(tester), 0);
      expect(_titleColor(tester, 'Главная'), accentText);

      await tester.tap(find.text('Настройки'));
      await tester.pump();

      expect(bar.selected, [2]);
      expect(_pillTop(tester), 0);

      await tester.pump(const Duration(milliseconds: 175));

      /// Halfway the pill is over the middle button
      expect(_pillTop(tester), closeTo(50, 10));
      expect(_titleColor(tester, 'Загрузки'), accentText);
      expect(_titleColor(tester, 'Главная'), isNot(accentText));

      await tester.pumpAndSettle();

      expect(_pillTop(tester), 100);
      expect(_titleColor(tester, 'Настройки'), accentText);
      expect(_titleColor(tester, 'Загрузки'), isNot(accentText));

      /// The selected page is not opened again
      await tester.tap(find.text('Настройки'));
      await tester.pumpAndSettle();

      expect(bar.selected, [2]);
      expect(find.text('3'), findsOneWidget);
    },
  );

  testWidgets('компактный навбар: только значки, названия в подсказках', (
    tester,
  ) async {
    final bar = _Bar();

    await bar.pump(tester, compact: true);

    expect(
      tester.getSize(find.byType(AppNavigationBar)).width,
      AppNavigationBar.compactWidth,
    );
    final downloads = _icon(Assets.icons.iconNavbarDownload.path);

    expect(find.text('Загрузки'), findsNothing);
    expect(downloads, findsOneWidget);
    expect(find.byTooltip('Загрузки'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(downloads);
    await tester.pumpAndSettle();

    expect(bar.selected, [1]);
  });
}
