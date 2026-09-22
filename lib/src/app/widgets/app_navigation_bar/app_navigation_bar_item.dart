part of 'app_navigation_bar.dart';

class _AppNavigationBarItem extends StatelessWidget {
  final AppNavigationBarItemData data;
  final double height;
  final bool compact;
  final bool selected;

  /// The selection pill is over the button: its content uses the pill colors
  final bool covered;
  final VoidCallback? onPressed;

  const _AppNavigationBarItem({
    required this.data,
    required this.height,
    required this.compact,
    required this.selected,
    required this.covered,
    this.onPressed,
  });

  Widget _badge(BuildContext context, int count) => Container(
    constraints: const BoxConstraints(minWidth: 20),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: covered ? context.color.onAccent : context.color.accentSubtle,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      count > 99 ? '99+' : '$count',
      textAlign: TextAlign.center,
      style: context.text.footnoteRegular.copyWith(color: context.color.accent),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final contentColor = covered
        ? context.color.onAccent
        : context.color.textSecondary;
    final badge = switch (data.badge) {
      final count? when count > 0 => count,
      _ => null,
    };

    final button = Semantics(
      selected: selected,
      label: compact ? data.title : null,
      child: AppPressable(
        /// The selected page is not opened again
        onPressed: selected ? null : onPressed,
        builder: (context, highlighted) => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: height,
          padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 16),
          decoration: BoxDecoration(
            color: highlighted && !covered
                ? context.color.hoverOverlay
                : context.color.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: compact
              ? Stack(
                  clipBehavior: Clip.none,
                  children: [
                    /// Fills the round button: the badge sits on its edge
                    Center(
                      child: SvgPicture.asset(
                        data.svgPictureFilePath,
                        height: 22,
                        width: 22,
                        color: contentColor,
                      ),
                    ),
                    if (badge != null)
                      Positioned(
                        top: -4,
                        right: -8,
                        child: _badge(context, badge),
                      ),
                  ],
                )
              : Row(
                  children: [
                    SvgPicture.asset(
                      data.svgPictureFilePath,
                      height: 20,
                      width: 20,
                      color: contentColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        data.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium.copyWith(
                          color: covered
                              ? context.color.onAccent
                              : context.color.textPrimary,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      _badge(context, badge),
                    ],
                  ],
                ),
        ),
      ),
    );

    if (!compact) return button;

    return Tooltip(
      message: data.title,
      waitDuration: const Duration(milliseconds: 300),
      preferBelow: false,
      child: button,
    );
  }
}
