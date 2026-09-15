import 'package:characters/characters.dart';

/// Text for native tray menus and tooltips.
///
/// Native menus do not shorten long items: a long video title would stretch
/// the menu across the screen. Shortening works on user-perceived characters,
/// so emoji and combined letters are never cut in half
abstract final class SystemTrayText {
  static const ellipsis = '…';

  /// Longest menu item in characters, the ellipsis included
  static const menuItemMaxLength = 48;

  /// Windows keeps at most 127 UTF-16 code units of a tray tooltip
  static const windowsToolTipMaxUtf16Length = 127;

  /// Cuts [text] to [maxLength] characters, ending it with an ellipsis
  static String ellipsize(String text, {int maxLength = menuItemMaxLength}) {
    final characters = text.trim().replaceAll(RegExp(r'\s+'), ' ').characters;

    if (characters.length <= maxLength) {
      return characters.string;
    }

    return '${characters.take(maxLength - 1).string.trimRight()}$ellipsis';
  }

  /// Cuts [text] to [maxUtf16Length] UTF-16 code units, ending it
  /// with an ellipsis, without splitting a character
  static String limitUtf16(String text, int maxUtf16Length) {
    if (text.length <= maxUtf16Length) {
      return text;
    }

    final buffer = StringBuffer();

    for (final character in text.characters) {
      if (buffer.length + character.length + ellipsis.length >
          maxUtf16Length) {
        break;
      }

      buffer.write(character);
    }

    return '${buffer.toString().trimRight()}$ellipsis';
  }

  /// Windows menus underline the letter after `&` as a keyboard shortcut:
  /// a literal ampersand is written twice
  static String escapeWindowsMenuMnemonics(String text) =>
      text.replaceAll('&', '&&');
}
