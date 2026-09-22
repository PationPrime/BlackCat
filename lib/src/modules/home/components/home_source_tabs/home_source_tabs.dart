import 'package:flutter/material.dart';
import 'package:peeky_cat/src/app/design_system/design_system.dart';
import 'package:peeky_cat/src/app/widgets/widgets.dart';

/// Video sites over the home pages: the chosen site is an accent pill,
/// as in the navigation bar
class HomeSourceTabs extends StatelessWidget {
  final List<String> titles;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  const HomeSourceTabs({
    super.key,
    required this.titles,
    required this.selectedIndex,
    this.onSelected,
  });

  /// A narrow window gets the tabs a little smaller: every site stays in view
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.color.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.color.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, title) in titles.indexed)
              _HomeSourceTab(
                title: title,
                selected: index == selectedIndex,
                onPressed: onSelected == null ? null : () => onSelected!(index),
              ),
          ],
        ),
      ),
    ),
  );
}

class _HomeSourceTab extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback? onPressed;

  const _HomeSourceTab({
    required this.title,
    required this.selected,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    inMutuallyExclusiveGroup: true,
    child: AppPressable(
      onPressed: onPressed,
      builder: (context, highlighted) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? context.color.accent
              : highlighted
              ? context.color.hoverOverlay
              : context.color.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          title,
          style: context.text.captionMedium.copyWith(
            color: selected
                ? context.color.onAccent
                : context.color.textSecondary,
          ),
        ),
      ),
    ),
  );
}
