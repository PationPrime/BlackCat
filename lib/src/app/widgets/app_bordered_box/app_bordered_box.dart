import 'package:flutter/widgets.dart';

import '../../design_system/design_system.dart';

/// Card with rounded corners and a border. Content is clipped to the corners
class AppBorderedBox extends StatelessWidget {
  final BorderRadius borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final Widget? child;

  const AppBorderedBox({
    super.key,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.borderColor,
    this.backgroundColor,
    this.padding,
    this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    padding: padding,
    decoration: BoxDecoration(
      color: backgroundColor ?? context.color.card,
      borderRadius: borderRadius,
      border: Border.all(color: borderColor ?? context.color.border),
    ),
    child: child,
  );
}
