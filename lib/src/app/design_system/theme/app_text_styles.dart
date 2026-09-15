import 'package:flutter/material.dart';

/// Базовые начертания шрифта. Цвет и кегль задаются в [AppThemeTextStyles]
abstract base class AppTextStyles {
  /// Системный шрифт Windows
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
