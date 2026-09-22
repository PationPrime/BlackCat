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
  static const white20 = Color(0x33FFFFFF);
  static const white30 = Color(0x4DFFFFFF);
  static const white50 = Color(0x80FFFFFF);
  static const white80 = Color(0xCCFFFFFF);

  // black
  static const black5 = Color(0x0D000000);
  static const black10 = Color(0x1A000000);
  static const black30 = Color(0x4D000000);
  static const black40 = Color(0x66000000);
  static const black50 = Color(0x80000000);
  static const black70 = Color(0xB3000000);
  static const black80 = Color(0xCC000000);
  static const black = Colors.black;

  // player
  static const youtubeRedFF0033 = Color(0xFFFF0033);
  static const gray282828Alpha90 = Color(0xE6282828);

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

  // violet: brand accent, Tailwind violet-400 and violet-500
  static const violetA78BFA = Color(0xFFA78BFA);
  static const violetA78BFAAlpha10 = Color(0x1AA78BFA);
  static const violetA78BFAAlpha12 = Color(0x1FA78BFA);
  static const violetA78BFAAlpha16 = Color(0x29A78BFA);
  static const violetA78BFAAlpha35 = Color(0x59A78BFA);
  static const violet8B5CF6 = Color(0xFF8B5CF6);

  // lava lamp of the background: the brand violets with Tailwind
  // violet and blue around them
  static const violetC4B5FD = Color(0xFFC4B5FD);
  static const violet6D28D9 = Color(0xFF6D28D9);
  static const violet5B21B6 = Color(0xFF5B21B6);
  static const blue93C5FD = Color(0xFF93C5FD);
  static const blue3B82F6 = Color(0xFF3B82F6);
  static const white70 = Color(0xB3FFFFFF);
  static const black8 = Color(0x14000000);

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
