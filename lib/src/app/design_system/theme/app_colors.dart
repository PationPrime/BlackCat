import 'package:flutter/material.dart';

/// App palette: raw colors without semantic meaning.
/// Widgets use them only through [AppThemeColors]
abstract base class AppColors {
  // transparent
  static const transparent = Colors.transparent;

  // white
  static const white = Colors.white;
  static const white5 = Color(0x0DFFFFFF);
  static const white10 = Color(0x1AFFFFFF);
  static const white30 = Color(0x4DFFFFFF);

  // black
  static const black5 = Color(0x0D000000);
  static const black10 = Color(0x1A000000);
  static const black30 = Color(0x4D000000);
  static const black40 = Color(0x66000000);
  static const black70 = Color(0xB3000000);

  // stone: warm grays
  static const stoneFAFAF9 = Color(0xFFFAFAF9);
  static const stoneF5F5F4 = Color(0xFFF5F5F4);
  static const stoneE7E5E4 = Color(0xFFE7E5E4);
  static const stoneD6D3D1 = Color(0xFFD6D3D1);
  static const stoneA8A29E = Color(0xFFA8A29E);
  static const stone78716C = Color(0xFF78716C);
  static const stone57534E = Color(0xFF57534E);
  static const stone44403C = Color(0xFF44403C);
  static const stone292524 = Color(0xFF292524);
  static const stone1C1917 = Color(0xFF1C1917);
  static const stone1C1917Alpha70 = Color(0xB31C1917);
  static const stone0C0A09 = Color(0xFF0C0A09);

  // amber: brand accent
  static const amberF59E0B = Color(0xFFF59E0B);
  static const amberF59E0BAlpha10 = Color(0x1AF59E0B);
  static const amberF59E0BAlpha12 = Color(0x1FF59E0B);
  static const amberF59E0BAlpha16 = Color(0x29F59E0B);
  static const amberF59E0BAlpha35 = Color(0x59F59E0B);
  static const amberD97706 = Color(0xFFD97706);
  static const amberD97706Alpha10 = Color(0x1AD97706);
  static const amberB45309 = Color(0xFFB45309);

  // red: errors
  static const redFEE2E2 = Color(0xFFFEE2E2);
  static const redFECACA = Color(0xFFFECACA);
  static const redFCA5A5 = Color(0xFFFCA5A5);
  static const redFCA5A5Alpha40 = Color(0x66FCA5A5);
  static const redF87171 = Color(0xFFF87171);
  static const redF87171Alpha10 = Color(0x1AF87171);
  static const redF87171Alpha30 = Color(0x4DF87171);
  static const redB91C1C = Color(0xFFB91C1C);
  static const redB91C1CAlpha40 = Color(0x66B91C1C);
  static const red991B1B = Color(0xFF991B1B);
  static const redC42B1C = Color(0xFFC42B1C);
}
