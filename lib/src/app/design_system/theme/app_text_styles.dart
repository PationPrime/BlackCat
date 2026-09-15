import 'package:flutter/material.dart';

/// Base font weights. Color and size are set in [AppThemeTextStyles]
abstract base class AppTextStyles {
  /// Windows system font
  static const _segoeUIFamily = 'Segoe UI';

  static const segoeUIRegular = TextStyle(
    fontFamily: _segoeUIFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Colors.black,
    height: 20 / 14,
  );

  static const segoeUIMedium = TextStyle(
    fontFamily: _segoeUIFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Colors.black,
    height: 20 / 14,
  );

  static const segoeUISemibold = TextStyle(
    fontFamily: _segoeUIFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.black,
    height: 20 / 14,
  );
}
