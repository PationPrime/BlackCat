// dart format width=80

/// GENERATED CODE - DO NOT MODIFY BY HAND
/// *****************************************************
///  FlutterGen
/// *****************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: deprecated_member_use,directives_ordering,implicit_dynamic_list_literal,unnecessary_import

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart' as _svg;
import 'package:vector_graphics/vector_graphics.dart' as _vg;

class $AssetsDonationsGen {
  const $AssetsDonationsGen();

  /// File path: assets/donations/boosty.png
  AssetGenImage get boosty =>
      const AssetGenImage('assets/donations/boosty.png');

  /// File path: assets/donations/donate_pay.png
  AssetGenImage get donatePay =>
      const AssetGenImage('assets/donations/donate_pay.png');

  /// File path: assets/donations/donation_alerts.png
  AssetGenImage get donationAlerts =>
      const AssetGenImage('assets/donations/donation_alerts.png');

  /// List of all assets
  List<AssetGenImage> get values => [boosty, donatePay, donationAlerts];
}

class $AssetsEjsGen {
  const $AssetsEjsGen();

  /// File path: assets/ejs/yt.solver.core.min.js
  String get ytSolverCoreMin => 'assets/ejs/yt.solver.core.min.js';

  /// File path: assets/ejs/yt.solver.lib.min.js
  String get ytSolverLibMin => 'assets/ejs/yt.solver.lib.min.js';

  /// List of all assets
  List<String> get values => [ytSolverCoreMin, ytSolverLibMin];
}

class $AssetsIconsGen {
  const $AssetsIconsGen();

  /// File path: assets/icons/icon_apple_logo.svg
  SvgGenImage get iconAppleLogo =>
      const SvgGenImage('assets/icons/icon_apple_logo.svg');

  /// File path: assets/icons/icon_windows_logo.svg
  SvgGenImage get iconWindowsLogo =>
      const SvgGenImage('assets/icons/icon_windows_logo.svg');

  /// List of all assets
  List<SvgGenImage> get values => [iconAppleLogo, iconWindowsLogo];
}

class $AssetsLangGen {
  const $AssetsLangGen();

  /// File path: assets/lang/en_US.json
  String get enUS => 'assets/lang/en_US.json';

  /// File path: assets/lang/ru_RU.json
  String get ruRU => 'assets/lang/ru_RU.json';

  /// List of all assets
  List<String> get values => [enUS, ruRU];
}

class $AssetsTrayGen {
  const $AssetsTrayGen();

  /// File path: assets/tray/tray_icon.ico
  String get trayIconIco => 'assets/tray/tray_icon.ico';

  /// File path: assets/tray/tray_icon.png
  AssetGenImage get trayIconPng =>
      const AssetGenImage('assets/tray/tray_icon.png');

  /// List of all assets
  List<dynamic> get values => [trayIconIco, trayIconPng];
}

abstract final class Assets {
  static const $AssetsDonationsGen donations = $AssetsDonationsGen();
  static const $AssetsEjsGen ejs = $AssetsEjsGen();
  static const $AssetsIconsGen icons = $AssetsIconsGen();
  static const $AssetsLangGen lang = $AssetsLangGen();
  static const $AssetsTrayGen tray = $AssetsTrayGen();
}

class AssetGenImage {
  const AssetGenImage(
    this._assetName, {
    this.size,
    this.flavors = const {},
    this.animation,
  });

  final String _assetName;

  final Size? size;
  final Set<String> flavors;
  final AssetGenImageAnimation? animation;

  Image image({
    Key? key,
    AssetBundle? bundle,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    double? scale,
    double? width,
    double? height,
    Color? color,
    Animation<double>? opacity,
    BlendMode? colorBlendMode,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect? centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = true,
    bool isAntiAlias = false,
    String? package,
    FilterQuality filterQuality = FilterQuality.medium,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    return Image.asset(
      _assetName,
      key: key,
      bundle: bundle,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      scale: scale,
      width: width,
      height: height,
      color: color,
      opacity: opacity,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      isAntiAlias: isAntiAlias,
      package: package,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  ImageProvider provider({AssetBundle? bundle, String? package}) {
    return AssetImage(_assetName, bundle: bundle, package: package);
  }

  String get path => _assetName;

  String get keyName => _assetName;
}

class AssetGenImageAnimation {
  const AssetGenImageAnimation({
    required this.isAnimation,
    required this.duration,
    required this.frames,
  });

  final bool isAnimation;
  final Duration duration;
  final int frames;
}

class SvgGenImage {
  const SvgGenImage(this._assetName, {this.size, this.flavors = const {}})
    : _isVecFormat = false;

  const SvgGenImage.vec(this._assetName, {this.size, this.flavors = const {}})
    : _isVecFormat = true;

  final String _assetName;
  final Size? size;
  final Set<String> flavors;
  final bool _isVecFormat;

  _svg.SvgPicture svg({
    Key? key,
    bool matchTextDirection = false,
    AssetBundle? bundle,
    String? package,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    AlignmentGeometry alignment = Alignment.center,
    bool allowDrawingOutsideViewBox = false,
    WidgetBuilder? placeholderBuilder,
    String? semanticsLabel,
    bool excludeFromSemantics = false,
    _svg.SvgTheme? theme,
    _svg.ColorMapper? colorMapper,
    ColorFilter? colorFilter,
    Clip clipBehavior = Clip.hardEdge,
    @deprecated Color? color,
    @deprecated BlendMode colorBlendMode = BlendMode.srcIn,
    @deprecated bool cacheColorFilter = false,
  }) {
    final _svg.BytesLoader loader;
    if (_isVecFormat) {
      loader = _vg.AssetBytesLoader(
        _assetName,
        assetBundle: bundle,
        packageName: package,
      );
    } else {
      loader = _svg.SvgAssetLoader(
        _assetName,
        assetBundle: bundle,
        packageName: package,
        theme: theme,
        colorMapper: colorMapper,
      );
    }
    return _svg.SvgPicture(
      loader,
      key: key,
      matchTextDirection: matchTextDirection,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      allowDrawingOutsideViewBox: allowDrawingOutsideViewBox,
      placeholderBuilder: placeholderBuilder,
      semanticsLabel: semanticsLabel,
      excludeFromSemantics: excludeFromSemantics,
      colorFilter:
          colorFilter ??
          (color == null ? null : ColorFilter.mode(color, colorBlendMode)),
      clipBehavior: clipBehavior,
      cacheColorFilter: cacheColorFilter,
    );
  }

  String get path => _assetName;

  String get keyName => _assetName;
}
