import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

/// Мягкое свечение сверху экрана:
/// `radial-gradient(circle at top, glow, transparent 40%)` поверх фона
class AppBackgroundGlow extends StatelessWidget {
  const AppBackgroundGlow({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        /// CSS считает радиус до дальнего угла, Flutter — в долях короткой стороны
        final farthestCorner = math.sqrt(width * width / 4 + height * height);

        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius:
                  0.4 * farthestCorner / math.max(1, math.min(width, height)),
              colors: [
                context.color.backgroundGlow,
                context.color.backgroundGlow.withValues(alpha: 0),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        );
      },
    ),
  );
}
