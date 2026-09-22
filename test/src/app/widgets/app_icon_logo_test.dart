import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:black_cat/src/app/widgets/widgets.dart';

void main() {
  /// The icon file the logo draws at [size] on a screen of [pixelRatio]
  Future<String> assetOf(
    WidgetTester tester, {
    required double size,
    double pixelRatio = 1,
  }) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(devicePixelRatio: pixelRatio),
        child: Center(child: AppIconLogo(size: size)),
      ),
    );

    final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));

    expect(tester.getSize(find.byType(SvgPicture)), Size.square(size));

    return (picture.bytesLoader as SvgAssetLoader).assetName;
  }

  testWidgets('мелкая иконка — без мелких деталей, как иконки 16–32 px', (
    tester,
  ) async {
    expect(
      await assetOf(tester, size: 28),
      'assets/app_icon/app_icon_small.svg',
    );
  });

  testWidgets('крупная иконка или экран высокой плотности — полная иконка', (
    tester,
  ) async {
    expect(await assetOf(tester, size: 40), 'assets/app_icon/app_icon.svg');
    expect(
      await assetOf(tester, size: 28, pixelRatio: 2),
      'assets/app_icon/app_icon.svg',
    );
  });
}
