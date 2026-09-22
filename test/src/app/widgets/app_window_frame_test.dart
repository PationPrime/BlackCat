import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peeky_cat/src/app/design_system/design_system.dart';
import 'package:peeky_cat/src/app/models/models.dart';
import 'package:peeky_cat/src/app/widgets/widgets.dart';

import '../../support/fake_services.dart';
import '../../support/test_localization.dart';

Future<void> _pump(
  WidgetTester tester, {
  required AppWindowFrameModel frame,
  bool isMaximized = false,
  bool isFullScreen = false,
  List<String>? calls,
  List<AppWindowResizeEdge>? edges,
  ValueChanged<double>? onTopPadding,
}) => tester.pumpWidget(
  MaterialApp(
    theme: AppThemeData.darkTheme,
    builder: (context, child) => AppWindowFrame(
      frame: frame,
      isMaximized: isMaximized,
      isFullScreen: isFullScreen,
      onMinimizePressed: () => calls?.add('minimize'),
      onToggleMaximizePressed: () => calls?.add('toggleMaximize'),
      onClosePressed: () => calls?.add('close'),
      onDragStarted: () => calls?.add('drag'),
      onResizeStarted: edges?.add,
      child: child!,
    ),
    home: Builder(
      builder: (context) {
        onTopPadding?.call(MediaQuery.paddingOf(context).top);

        return const Scaffold(body: Text('Экран'));
      },
    ),
  ),
);

void main() {
  setUpAll(loadTestTranslations);

  testWidgets('системная рамка: экран без заголовка и кнопок', (tester) async {
    await _pump(tester, frame: const AppWindowFrameModel.system());

    expect(find.text('Экран'), findsOneWidget);
    expect(find.bySemanticsLabel('Закрыть'), findsNothing);
  });

  testWidgets('Windows: кнопки окна, отступ под заголовок и перетаскивание', (
    tester,
  ) async {
    final calls = <String>[];
    double? topPadding;

    await _pump(
      tester,
      frame: windowsFrame,
      calls: calls,
      onTopPadding: (value) => topPadding = value,
    );

    expect(topPadding, AppWindowFrame.titleBarHeight);

    await tester.tap(find.bySemanticsLabel('Свернуть'));
    await tester.tap(find.bySemanticsLabel('Развернуть'));
    await tester.tap(find.bySemanticsLabel('Закрыть'));
    await tester.drag(
      find.byWidgetPredicate(
        (widget) => widget is GestureDetector && widget.onDoubleTap != null,
      ),
      const Offset(40, 0),
    );

    /// Lets the double click recognizer of the title bar time out
    await tester.pump(const Duration(seconds: 1));

    expect(calls, ['minimize', 'toggleMaximize', 'close', 'drag']);
  });

  testWidgets(
    'развёрнутое окно: кнопка «Восстановить» и нет полос изменения размера',
    (tester) async {
      await _pump(tester, frame: windowsFrame, isMaximized: true);

      expect(find.bySemanticsLabel('Восстановить'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is MouseRegion &&
              widget.cursor == SystemMouseCursors.resizeUpDown,
        ),
        findsNothing,
      );
    },
  );

  testWidgets('верхний край окна тянется за полосу изменения размера', (
    tester,
  ) async {
    final edges = <AppWindowResizeEdge>[];

    await _pump(tester, frame: windowsFrame, edges: edges);

    final topEdge = find.byWidgetPredicate(
      (widget) =>
          widget is MouseRegion &&
          widget.cursor == SystemMouseCursors.resizeUpDown,
    );

    await tester.drag(topEdge, const Offset(0, -30));

    expect(edges, [AppWindowResizeEdge.top]);
  });

  testWidgets('macOS: место под нативные кнопки, своих кнопок нет', (
    tester,
  ) async {
    await _pump(
      tester,
      frame: const AppWindowFrameModel(isCustom: true, leadingInset: 76),
    );

    expect(find.bySemanticsLabel('Закрыть'), findsNothing);
    expect(find.text('Экран'), findsOneWidget);
  });

  testWidgets(
    'полный экран: ни заголовка, ни отступа под него, ни полос изменения размера',
    (tester) async {
      double? topPadding;

      await _pump(
        tester,
        frame: windowsFrame,
        isFullScreen: true,
        onTopPadding: (value) => topPadding = value,
      );

      expect(topPadding, 0);
      expect(find.bySemanticsLabel('Закрыть'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is MouseRegion &&
              widget.cursor == SystemMouseCursors.resizeUpDown,
        ),
        findsNothing,
      );
      expect(find.text('Экран'), findsOneWidget);
    },
  );
}
