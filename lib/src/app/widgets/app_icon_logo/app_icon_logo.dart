import 'package:flutter/material.dart';

import '../../../generated/assets/assets.gen.dart';

/// The app icon: the black cat peeking from the corner of the violet tile,
/// the same drawing as the icon of the app window and the Dock
class AppIconLogo extends StatelessWidget {
  /// Up to this many physical pixels the icon without the small details
  /// is drawn, as for the 16–32 px platform icons
  static const _smallIconPixels = 32.0;

  /// Width and height of the icon
  final double size;

  const AppIconLogo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final pixels = size * MediaQuery.devicePixelRatioOf(context);
    final icon = pixels <= _smallIconPixels
        ? Assets.appIcon.appIconSmall
        : Assets.appIcon.appIcon;

    return icon.svg(width: size, height: size, excludeFromSemantics: true);
  }
}
