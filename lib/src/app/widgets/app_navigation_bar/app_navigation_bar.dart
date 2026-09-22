import 'dart:ui' show lerpDouble;

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../design_system/design_system.dart';
import '../app_buttons/app_buttons.dart';

part 'app_navigation_bar_item.dart';
part 'app_navigation_bar_item_data.dart';

/// Vertical navigation bar: round buttons with an icon and a title.
///
/// The selection pill slides to the chosen button; a button turns selected
/// as soon as the pill covers most of it, so the colors change along the way.
/// [compact] leaves only the icons, the titles move to tooltips
class AppNavigationBar extends StatefulWidget {
  static const expandedWidth = 216.0;
  static const compactWidth = 76.0;

  final List<AppNavigationBarItemData> items;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  /// Above the buttons, e.g. the app name
  final Widget? header;

  /// Pinned to the bottom, e.g. the account state
  final Widget? footer;
  final bool compact;
  final double itemHeight;
  final double itemSpacing;
  final Duration selectionDuration;

  const AppNavigationBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    this.onSelected,
    this.header,
    this.footer,
    this.compact = false,
    this.itemHeight = 44,
    this.itemSpacing = 6,
    this.selectionDuration = const Duration(milliseconds: 350),
  });

  @override
  State<AppNavigationBar> createState() => _AppNavigationBarState();
}

class _AppNavigationBarState extends State<AppNavigationBar>
    with SingleTickerProviderStateMixin {
  late final _selectionController = AnimationController(
    vsync: this,
    duration: widget.selectionDuration,
    value: 1,
  );
  late final _selectionAnimation = CurvedAnimation(
    parent: _selectionController,
    curve: Curves.easeInOutCubic,
  );

  /// Pill position in buttons: `1.5` is halfway between the second
  /// and the third button
  late double _from = widget.selectedIndex.toDouble();
  late double _to = widget.selectedIndex.toDouble();

  double get _position =>
      lerpDouble(_from, _to, _selectionAnimation.value) ?? _to;

  @override
  void didUpdateWidget(covariant AppNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _from = _position;
      _to = widget.selectedIndex.toDouble();
      _selectionController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _selectionAnimation.dispose();
    _selectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.itemHeight + widget.itemSpacing;

    /// In the compact bar the buttons are circles
    final horizontalPadding = widget.compact
        ? (AppNavigationBar.compactWidth - widget.itemHeight) / 2
        : 14.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: widget.compact
          ? AppNavigationBar.compactWidth
          : AppNavigationBar.expandedWidth,
      decoration: BoxDecoration(
        color: context.color.surface,
        border: Border(right: BorderSide(color: context.color.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?widget.header,
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 8,
              ),
              child: AnimatedBuilder(
                animation: _selectionAnimation,
                builder: (context, _) {
                  final position = _position;

                  return Stack(
                    children: [
                      Positioned(
                        top: position * step,
                        left: 0,
                        right: 0,
                        height: widget.itemHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: context.color.accent,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: context.color.accent.withValues(
                                  alpha: 0.18,
                                ),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          for (final (index, item) in widget.items.indexed)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: index == widget.items.length - 1
                                    ? 0
                                    : widget.itemSpacing,
                              ),
                              child: _AppNavigationBarItem(
                                data: item,
                                height: widget.itemHeight,
                                compact: widget.compact,
                                selected: index == widget.selectedIndex,

                                /// The pill covers more than half of the button
                                covered: (position - index).abs() < 0.5,
                                onPressed: widget.onSelected == null
                                    ? null
                                    : () => widget.onSelected!(index),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          ?widget.footer,
        ],
      ),
    );
  }
}
