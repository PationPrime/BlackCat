import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

/// Полоса прогресса. [pulsing]: мигает, пока длится неопределённый этап
class AppProgressBar extends StatefulWidget {
  /// От 0 до 1
  final double value;
  final bool pulsing;
  final double height;

  const AppProgressBar({
    super.key,
    required this.value,
    this.pulsing = false,
    this.height = 8,
  });

  @override
  State<AppProgressBar> createState() => _AppProgressBarState();
}

class _AppProgressBarState extends State<AppProgressBar>
    with SingleTickerProviderStateMixin {
  /// Как `animate-pulse` в Tailwind: прозрачность 1 → 0.5 → 1 за 2 секунды
  late final _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );
  late final _pulseOpacity = Tween<double>(
    begin: 1,
    end: 0.5,
  ).animate(_pulseController);

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant AppProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    if (widget.pulsing) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }

      return;
    }

    _pulseController
      ..stop()
      ..value = 0;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: SizedBox(
      height: widget.height,
      child: ColoredBox(
        color: context.color.border,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FadeTransition(
            opacity: _pulseOpacity,
            child: AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 150),
              widthFactor: widget.value.clamp(0, 1),
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.color.accent,
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
