import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppThemeColors extends ThemeExtension<AppThemeColors> {
  /// Screen background
  final Color background;

  /// Glow in the screen header
  final Color backgroundGlow;

  /// Input fields and panels over the background
  final Color surface;

  /// Cards
  final Color card;

  /// Dialog background
  final Color dialog;

  /// Screen dimming under a dialog
  final Color scrim;

  final Color border;
  final Color borderHover;

  /// Hover highlight of transparent buttons
  final Color hoverOverlay;

  /// Primary text: card titles, input
  final Color textPrimary;

  /// App name in the header
  final Color textHeader;

  /// Secondary text: button titles, progress
  final Color textSecondary;

  /// Metadata: channel, duration, statuses
  final Color textTertiary;

  /// Hints, group titles, inactive elements
  final Color textHint;

  final Color iconPrimary;
  final Color iconDisabled;

  /// Brand accent: primary button, selection, progress
  final Color accent;
  final Color accentHover;

  /// Selected item background
  final Color accentSubtle;

  /// Text selection
  final Color textSelection;

  /// Text and icons on the accent background
  final Color onAccent;

  /// Neutral button ("Search")
  final Color buttonNeutral;
  final Color buttonNeutralHover;
  final Color onButtonNeutral;

  final Color errorBackground;
  final Color errorBorder;
  final Color errorText;

  /// Action button inside an error message
  final Color errorActionText;
  final Color errorActionBorder;
  final Color errorActionHover;

  /// Close button of the app title bar on hover, as on Windows
  final Color windowCloseHover;
  final Color onWindowCloseHover;

  /// QR code plate and modules: dark on light in both themes, as cameras
  /// read QR codes best
  final Color qrBackground;
  final Color qrForeground;

  /// Player background and letterbox bars: black in both themes
  final Color player;

  /// Icons and text over the video
  final Color onPlayer;

  /// Secondary text over the video: the duration
  final Color onPlayerSecondary;

  /// Shade under the player controls and the thumbnail badges
  final Color playerShade;

  /// Round backs of the pause flash and the seek hint
  final Color playerOverlay;

  /// Played part of the progress bar and of a watched thumbnail, as on YouTube
  final Color playerProgress;

  /// Read-ahead part of the progress bar
  final Color playerBuffered;

  /// Rest of the progress bar
  final Color playerTrack;

  /// Hover highlight of the player buttons
  final Color playerHover;

  /// Player menus: the playback speed
  final Color playerMenu;

  final Color transparent;

  const AppThemeColors({
    required this.background,
    required this.backgroundGlow,
    required this.surface,
    required this.card,
    required this.dialog,
    required this.scrim,
    required this.border,
    required this.borderHover,
    required this.hoverOverlay,
    required this.textPrimary,
    required this.textHeader,
    required this.textSecondary,
    required this.textTertiary,
    required this.textHint,
    required this.iconPrimary,
    required this.iconDisabled,
    required this.accent,
    required this.accentHover,
    required this.accentSubtle,
    required this.textSelection,
    required this.onAccent,
    required this.buttonNeutral,
    required this.buttonNeutralHover,
    required this.onButtonNeutral,
    required this.errorBackground,
    required this.errorBorder,
    required this.errorText,
    required this.errorActionText,
    required this.errorActionBorder,
    required this.errorActionHover,
    required this.windowCloseHover,
    required this.onWindowCloseHover,
    required this.qrBackground,
    required this.qrForeground,
    required this.player,
    required this.onPlayer,
    required this.onPlayerSecondary,
    required this.playerShade,
    required this.playerOverlay,
    required this.playerProgress,
    required this.playerBuffered,
    required this.playerTrack,
    required this.playerHover,
    required this.playerMenu,
    required this.transparent,
  });

  @override
  AppThemeColors copyWith({
    Color? background,
    Color? backgroundGlow,
    Color? surface,
    Color? card,
    Color? dialog,
    Color? scrim,
    Color? border,
    Color? borderHover,
    Color? hoverOverlay,
    Color? textPrimary,
    Color? textHeader,
    Color? textSecondary,
    Color? textTertiary,
    Color? textHint,
    Color? iconPrimary,
    Color? iconDisabled,
    Color? accent,
    Color? accentHover,
    Color? accentSubtle,
    Color? textSelection,
    Color? onAccent,
    Color? buttonNeutral,
    Color? buttonNeutralHover,
    Color? onButtonNeutral,
    Color? errorBackground,
    Color? errorBorder,
    Color? errorText,
    Color? errorActionText,
    Color? errorActionBorder,
    Color? errorActionHover,
    Color? windowCloseHover,
    Color? onWindowCloseHover,
    Color? qrBackground,
    Color? qrForeground,
    Color? player,
    Color? onPlayer,
    Color? onPlayerSecondary,
    Color? playerShade,
    Color? playerOverlay,
    Color? playerProgress,
    Color? playerBuffered,
    Color? playerTrack,
    Color? playerHover,
    Color? playerMenu,
    Color? transparent,
  }) => AppThemeColors(
    background: background ?? this.background,
    backgroundGlow: backgroundGlow ?? this.backgroundGlow,
    surface: surface ?? this.surface,
    card: card ?? this.card,
    dialog: dialog ?? this.dialog,
    scrim: scrim ?? this.scrim,
    border: border ?? this.border,
    borderHover: borderHover ?? this.borderHover,
    hoverOverlay: hoverOverlay ?? this.hoverOverlay,
    textPrimary: textPrimary ?? this.textPrimary,
    textHeader: textHeader ?? this.textHeader,
    textSecondary: textSecondary ?? this.textSecondary,
    textTertiary: textTertiary ?? this.textTertiary,
    textHint: textHint ?? this.textHint,
    iconPrimary: iconPrimary ?? this.iconPrimary,
    iconDisabled: iconDisabled ?? this.iconDisabled,
    accent: accent ?? this.accent,
    accentHover: accentHover ?? this.accentHover,
    accentSubtle: accentSubtle ?? this.accentSubtle,
    textSelection: textSelection ?? this.textSelection,
    onAccent: onAccent ?? this.onAccent,
    buttonNeutral: buttonNeutral ?? this.buttonNeutral,
    buttonNeutralHover: buttonNeutralHover ?? this.buttonNeutralHover,
    onButtonNeutral: onButtonNeutral ?? this.onButtonNeutral,
    errorBackground: errorBackground ?? this.errorBackground,
    errorBorder: errorBorder ?? this.errorBorder,
    errorText: errorText ?? this.errorText,
    errorActionText: errorActionText ?? this.errorActionText,
    errorActionBorder: errorActionBorder ?? this.errorActionBorder,
    errorActionHover: errorActionHover ?? this.errorActionHover,
    windowCloseHover: windowCloseHover ?? this.windowCloseHover,
    onWindowCloseHover: onWindowCloseHover ?? this.onWindowCloseHover,
    qrBackground: qrBackground ?? this.qrBackground,
    qrForeground: qrForeground ?? this.qrForeground,
    player: player ?? this.player,
    onPlayer: onPlayer ?? this.onPlayer,
    onPlayerSecondary: onPlayerSecondary ?? this.onPlayerSecondary,
    playerShade: playerShade ?? this.playerShade,
    playerOverlay: playerOverlay ?? this.playerOverlay,
    playerProgress: playerProgress ?? this.playerProgress,
    playerBuffered: playerBuffered ?? this.playerBuffered,
    playerTrack: playerTrack ?? this.playerTrack,
    playerHover: playerHover ?? this.playerHover,
    playerMenu: playerMenu ?? this.playerMenu,
    transparent: transparent ?? this.transparent,
  );

  @override
  ThemeExtension<AppThemeColors> lerp(
    ThemeExtension<AppThemeColors>? other,
    double t,
  ) {
    if (other is! AppThemeColors) {
      return this;
    }

    return AppThemeColors(
      background: Color.lerp(background, other.background, t)!,
      backgroundGlow: Color.lerp(backgroundGlow, other.backgroundGlow, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      dialog: Color.lerp(dialog, other.dialog, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderHover: Color.lerp(borderHover, other.borderHover, t)!,
      hoverOverlay: Color.lerp(hoverOverlay, other.hoverOverlay, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textHeader: Color.lerp(textHeader, other.textHeader, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      iconPrimary: Color.lerp(iconPrimary, other.iconPrimary, t)!,
      iconDisabled: Color.lerp(iconDisabled, other.iconDisabled, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      accentSubtle: Color.lerp(accentSubtle, other.accentSubtle, t)!,
      textSelection: Color.lerp(textSelection, other.textSelection, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      buttonNeutral: Color.lerp(buttonNeutral, other.buttonNeutral, t)!,
      buttonNeutralHover: Color.lerp(
        buttonNeutralHover,
        other.buttonNeutralHover,
        t,
      )!,
      onButtonNeutral: Color.lerp(onButtonNeutral, other.onButtonNeutral, t)!,
      errorBackground: Color.lerp(errorBackground, other.errorBackground, t)!,
      errorBorder: Color.lerp(errorBorder, other.errorBorder, t)!,
      errorText: Color.lerp(errorText, other.errorText, t)!,
      errorActionText: Color.lerp(errorActionText, other.errorActionText, t)!,
      errorActionBorder: Color.lerp(
        errorActionBorder,
        other.errorActionBorder,
        t,
      )!,
      errorActionHover: Color.lerp(
        errorActionHover,
        other.errorActionHover,
        t,
      )!,
      windowCloseHover: Color.lerp(
        windowCloseHover,
        other.windowCloseHover,
        t,
      )!,
      onWindowCloseHover: Color.lerp(
        onWindowCloseHover,
        other.onWindowCloseHover,
        t,
      )!,
      qrBackground: Color.lerp(qrBackground, other.qrBackground, t)!,
      qrForeground: Color.lerp(qrForeground, other.qrForeground, t)!,
      player: Color.lerp(player, other.player, t)!,
      onPlayer: Color.lerp(onPlayer, other.onPlayer, t)!,
      onPlayerSecondary: Color.lerp(
        onPlayerSecondary,
        other.onPlayerSecondary,
        t,
      )!,
      playerShade: Color.lerp(playerShade, other.playerShade, t)!,
      playerOverlay: Color.lerp(playerOverlay, other.playerOverlay, t)!,
      playerProgress: Color.lerp(playerProgress, other.playerProgress, t)!,
      playerBuffered: Color.lerp(playerBuffered, other.playerBuffered, t)!,
      playerTrack: Color.lerp(playerTrack, other.playerTrack, t)!,
      playerHover: Color.lerp(playerHover, other.playerHover, t)!,
      playerMenu: Color.lerp(playerMenu, other.playerMenu, t)!,
      transparent: Color.lerp(transparent, other.transparent, t)!,
    );
  }

  static const light = AppThemeColors(
    background: AppColors.stoneFAFAF9,
    backgroundGlow: AppColors.violetA78BFAAlpha12,
    surface: AppColors.white,
    card: AppColors.white,
    dialog: AppColors.white,
    scrim: AppColors.black40,
    border: AppColors.black10,
    borderHover: AppColors.black30,
    hoverOverlay: AppColors.black5,
    textPrimary: AppColors.stone1C1917,
    textHeader: AppColors.stone0C0A09,
    textSecondary: AppColors.stone44403C,
    textTertiary: AppColors.stone57534E,
    textHint: AppColors.stoneA8A29E,
    iconPrimary: AppColors.stone44403C,
    iconDisabled: AppColors.stoneA8A29E,
    accent: AppColors.violetA78BFA,
    accentHover: AppColors.violet8B5CF6,
    accentSubtle: AppColors.violetA78BFAAlpha10,
    textSelection: AppColors.violetA78BFAAlpha35,
    onAccent: AppColors.stone0C0A09,
    buttonNeutral: AppColors.stone1C1917,
    buttonNeutralHover: AppColors.stone292524,
    onButtonNeutral: AppColors.stoneFAFAF9,
    errorBackground: AppColors.redF87171Alpha10,
    errorBorder: AppColors.redF87171Alpha30,
    errorText: AppColors.redB91C1C,
    errorActionText: AppColors.red991B1B,
    errorActionBorder: AppColors.redB91C1CAlpha40,
    errorActionHover: AppColors.redF87171Alpha10,
    windowCloseHover: AppColors.redC42B1C,
    onWindowCloseHover: AppColors.white,
    qrBackground: AppColors.stoneFAFAF9,
    qrForeground: AppColors.stone0C0A09,
    player: AppColors.black,
    onPlayer: AppColors.white,
    onPlayerSecondary: AppColors.white80,
    playerShade: AppColors.black80,
    playerOverlay: AppColors.black50,
    playerProgress: AppColors.youtubeRedFF0033,
    playerBuffered: AppColors.white50,
    playerTrack: AppColors.white20,
    playerHover: AppColors.white10,
    playerMenu: AppColors.gray282828Alpha90,
    transparent: AppColors.transparent,
  );

  static const dark = AppThemeColors(
    background: AppColors.stone0C0A09,
    backgroundGlow: AppColors.violetA78BFAAlpha16,
    surface: AppColors.stone1C1917,
    card: AppColors.stone1C1917Alpha70,
    dialog: AppColors.stone1C1917,
    scrim: AppColors.black70,
    border: AppColors.white10,
    borderHover: AppColors.white30,
    hoverOverlay: AppColors.white5,
    textPrimary: AppColors.stoneFAFAF9,
    textHeader: AppColors.stoneF5F5F4,
    textSecondary: AppColors.stoneD6D3D1,
    textTertiary: AppColors.stoneA8A29E,
    textHint: AppColors.stone78716C,
    iconPrimary: AppColors.stoneD6D3D1,
    iconDisabled: AppColors.stone78716C,
    accent: AppColors.violetA78BFA,
    accentHover: AppColors.violet8B5CF6,
    accentSubtle: AppColors.violetA78BFAAlpha10,
    textSelection: AppColors.violetA78BFAAlpha35,
    onAccent: AppColors.stone0C0A09,
    buttonNeutral: AppColors.stoneF5F5F4,
    buttonNeutralHover: AppColors.white,
    onButtonNeutral: AppColors.stone0C0A09,
    errorBackground: AppColors.redF87171Alpha10,
    errorBorder: AppColors.redF87171Alpha30,
    errorText: AppColors.redFECACA,
    errorActionText: AppColors.redFEE2E2,
    errorActionBorder: AppColors.redFCA5A5Alpha40,
    errorActionHover: AppColors.redF87171Alpha10,
    windowCloseHover: AppColors.redC42B1C,
    onWindowCloseHover: AppColors.white,
    qrBackground: AppColors.stoneFAFAF9,
    qrForeground: AppColors.stone0C0A09,
    player: AppColors.black,
    onPlayer: AppColors.white,
    onPlayerSecondary: AppColors.white80,
    playerShade: AppColors.black80,
    playerOverlay: AppColors.black50,
    playerProgress: AppColors.youtubeRedFF0033,
    playerBuffered: AppColors.white50,
    playerTrack: AppColors.white20,
    playerHover: AppColors.white10,
    playerMenu: AppColors.gray282828Alpha90,
    transparent: AppColors.transparent,
  );
}
