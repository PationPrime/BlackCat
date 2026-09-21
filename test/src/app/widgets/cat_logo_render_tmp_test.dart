import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:black_cat/src/app/design_system/design_system.dart';
import 'package:black_cat/src/app/widgets/widgets.dart';

/// Temporary: renders the logo into PNG files for a look
void main() {
  const out =
      r'C:\Users\patio\AppData\Local\Temp\claude\F--youtube-downloader'
      r'\f68f6729-86a1-4716-bd46-97ad19bcd6ac\scratchpad\icon';

  for (final (name, theme, background) in [
    ('light', AppThemeData.lightTheme, AppThemeColors.light.surface),
    ('dark', AppThemeData.darkTheme, AppThemeColors.dark.surface),
  ]) {
    testWidgets('логотип $name', (tester) async {
      final key = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: background,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AppCatLogo(size: 240),
                    SizedBox(width: 24),
                    AppCatLogo(size: 64),
                    SizedBox(width: 16),
                    AppCatLogo(),
                    SizedBox(width: 16),
                    AppCatLogo(size: 20),
                    SizedBox(width: 16),
                    AppCatLogo(size: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

      File('$out/logo_$name.png').writeAsBytesSync(
        bytes!.buffer.asUint8List(),
      );
    });
  }
}
