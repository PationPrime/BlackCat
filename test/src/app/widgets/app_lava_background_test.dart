import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peeky_cat/src/app/design_system/design_system.dart';
import 'package:peeky_cat/src/app/widgets/app_lava_background/lava_lamp_motion.dart';
import 'package:peeky_cat/src/app/widgets/app_lava_background/lava_lamp_palette.dart';
import 'package:peeky_cat/src/app/widgets/app_lava_background/render_lava_lamp.dart';
import 'package:peeky_cat/src/app/widgets/widgets.dart';

/// Five frames, each longer than a tick of the lamp timer
const _frame = Duration(milliseconds: 40);

Future<void> _pump(
  WidgetTester tester, {
  bool animate = true,
  bool tickers = true,
  bool disableAnimations = false,
}) => tester.pumpWidget(
  MaterialApp(
    theme: AppThemeData.darkTheme,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: TickerMode(
          enabled: tickers,
          child: AppLavaBackground(animate: animate),
        ),
      ),
    ),
  ),
);

/// The shader loads outside the fake time of the test
Future<RenderLavaLamp> _lamp(WidgetTester tester) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    /// Every widget above the lamp reports its render object too
    final lamps = tester.allRenderObjects.whereType<RenderLavaLamp>().toSet();

    if (lamps.isNotEmpty) return lamps.single;

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }

  fail('Шейдер лавы не загрузился');
}

Future<int> _paintsOverFrames(WidgetTester tester, RenderLavaLamp lamp) async {
  final before = lamp.debugPaintCount;

  for (var i = 0; i < 5; i++) {
    await tester.pump(_frame);
  }

  return lamp.debugPaintCount - before;
}

void main() {
  group('движение лавы', () {
    test(
      'в одно и то же время капли на тех же местах, их столько, сколько берёт шейдер',
      () {
        final blobs = LavaLampMotion.at(75, aspect: 1.6);

        expect(LavaLampMotion.count, 6);
        expect(blobs, hasLength(LavaLampMotion.count));
        expect(LavaLampMotion.at(75, aspect: 1.6), blobs);
        expect(LavaLampMotion.at(76, aspect: 1.6), isNot(blobs));
      },
    );

    test('капли плывут плавно: за кадр каждая сдвигается едва заметно', () {
      const aspect = 1.6;
      const frame = 1 / RenderLavaLamp.framesPerSecond;
      var previous = LavaLampMotion.at(0, aspect: aspect);
      var largestStep = 0.0;
      var largestGrowth = 0.0;

      for (var seconds = frame; seconds < 900; seconds += frame) {
        final blobs = LavaLampMotion.at(seconds, aspect: aspect);

        for (final (index, blob) in blobs.indexed) {
          final before = previous[index];

          largestStep = math.max(
            largestStep,
            math.sqrt(
              math.pow(blob.x - before.x, 2) + math.pow(blob.y - before.y, 2),
            ),
          );
          largestGrowth = math.max(
            largestGrowth,
            (blob.radius - before.radius).abs(),
          );
        }

        previous = blobs;
      }

      /// In heights of the window
      expect(largestStep, lessThan(0.01));
      expect(largestGrowth, lessThan(0.001));
    });

    test(
      'в окне любой формы лава есть всегда: хоть одна плотная капля внутри',
      () {
        for (final aspect in [1.2, 1.6, 2.2]) {
          for (var seconds = 0.0; seconds < 3600; seconds += 0.5) {
            final inside = LavaLampMotion.at(seconds, aspect: aspect).where(
              (blob) =>
                  blob.weight >= 0.9 &&
                  blob.x >= 0 &&
                  blob.x <= aspect &&
                  blob.y >= 0 &&
                  blob.y <= 1,
            );

            expect(inside, isNotEmpty, reason: '$aspect, $seconds с');
          }
        }
      },
    );
  });

  test(
    'лава под вуалью, как под карточкой, а фон без лавы остаётся прежним',
    () {
      final colors = AppThemeColors.dark;
      final palette = LavaLampPalette(
        base: colors.background,
        haze: colors.lavaHaze,
        body: colors.lavaBody,
        core: colors.lavaCore,
        deep: colors.lavaDeep,
        veil: colors.lavaVeil,
        grain: colors.lavaGrain,
      );

      expect(colors.lavaVeil, colors.card);
      expect(palette.shaderColors, [
        colors.background,
        for (final lava in [
          colors.lavaHaze,
          colors.lavaBody,
          colors.lavaCore,
          colors.lavaDeep,
        ])
          Color.alphaBlend(colors.card, lava),
      ]);
    },
  );

  test(
    'зерно — редкие крапинки цвета зерна, одни и те же при каждом запуске',
    () {
      const grain = Color(0x73000000);
      final pixels = LavaLampGrain.pixels(grain);
      final alphas = [for (var i = 3; i < pixels.length; i += 4) pixels[i]];

      expect(
        pixels,
        hasLength(LavaLampGrain.tileSize * LavaLampGrain.tileSize * 4),
      );
      expect(LavaLampGrain.pixels(grain), pixels);

      /// Black specks, no darker than the grain alpha
      expect(
        {
          for (var i = 0; i < pixels.length; i += 4)
            (pixels[i], pixels[i + 1], pixels[i + 2]),
        },
        {(0, 0, 0)},
      );
      expect(alphas.reduce(math.max), inInclusiveRange(0x70, 0x73));

      /// Most of the tile stays clear
      expect(
        alphas.where((alpha) => alpha == 0).length / alphas.length,
        closeTo(0.55, 0.02),
      );
    },
  );

  testWidgets(
    'лава — отдельный слой на всё место: перерисовывается по таймеру и пропускает нажатия',
    (tester) async {
      await _pump(tester);

      final lamp = await _lamp(tester);

      expect(lamp.isRepaintBoundary, isTrue);
      expect(
        lamp.size,
        tester.view.physicalSize / tester.view.devicePixelRatio,
      );
      expect(lamp.animating, isTrue);
      expect(await _paintsOverFrames(tester, lamp), 5);
      expect(
        lamp.hitTest(BoxHitTestResult(), position: const Offset(100, 100)),
        isFalse,
      );
    },
  );

  testWidgets(
    'лава замирает без анимации, на скрытой вкладке и когда система просит меньше движения',
    (tester) async {
      await _pump(tester);

      final lamp = await _lamp(tester);

      for (final (animate, tickers, disableAnimations) in [
        (false, true, false),
        (true, false, false),
        (true, true, true),
      ]) {
        await _pump(
          tester,
          animate: animate,
          tickers: tickers,
          disableAnimations: disableAnimations,
        );

        expect(lamp.animating, isFalse);
        expect(await _paintsOverFrames(tester, lamp), 0);

        await _pump(tester);

        expect(lamp.animating, isTrue);
        expect(await _paintsOverFrames(tester, lamp), 5);
      }
    },
  );

  testWidgets(
    'лава замирает, пока окно свёрнуто, и оживает, когда его показали',
    (tester) async {
      await _pump(tester);

      final lamp = await _lamp(tester);

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();

      expect(lamp.animating, isFalse);
      expect(await _paintsOverFrames(tester, lamp), 0);

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(lamp.animating, isTrue);
      expect(await _paintsOverFrames(tester, lamp), 5);
    },
  );
}
