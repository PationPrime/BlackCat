import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../errors/errors.dart';
import '../models/models.dart';
import 'netscape_cookies.dart';

/// Checks a cookies.txt chosen by the user and keeps its YouTube and Google
/// cookies. Throws [AuthenticationException] with the reason otherwise
abstract final class CookiesFileParser {
  /// Browsers export youtube.com cookies in a few kilobytes
  static const maxFileBytes = 5 << 20;

  static const _extension = '.txt';

  /// Control characters other than tabs and line breaks mean binary data
  static final _binaryPattern = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');

  static List<BrowserCookieModel> parse(
    Uint8List bytes, {
    required String fileName,
    DateTime? now,
  }) {
    const codes = AuthenticationErrorCodes();

    if (p.extension(fileName).toLowerCase() != _extension) {
      throw AuthenticationException(codes.cookiesNotText);
    }

    if (bytes.length > maxFileBytes) {
      throw AuthenticationException(codes.cookiesTooLarge);
    }

    final text = decodeText(bytes);

    if (text == null) {
      throw AuthenticationException(codes.cookiesNotText);
    }

    final content = text.trimLeft();

    /// Some extensions export JSON: yt-dlp does not read it
    if (content.startsWith('[') || content.startsWith('{')) {
      throw AuthenticationException(codes.cookiesJson);
    }

    final cookies = NetscapeCookies.decode(text);

    if (cookies.isEmpty) {
      throw AuthenticationException(codes.cookiesFormat);
    }

    final accountCookies = cookies
        .where(NetscapeCookies.isYouTubeOrGoogle)
        .toList();

    if (!accountCookies.any(
      (cookie) => NetscapeCookies.isYouTube(cookie.domain),
    )) {
      throw AuthenticationException(codes.cookiesNoYouTube);
    }

    if (!NetscapeCookies.hasYouTubeSession(accountCookies, now: now)) {
      /// The session cookies are there, only their time has passed
      final expired = NetscapeCookies.hasYouTubeSession(
        accountCookies,
        now: DateTime.fromMillisecondsSinceEpoch(0),
      );

      throw AuthenticationException(
        expired ? codes.cookiesExpired : codes.cookiesNoSession,
      );
    }

    return accountCookies;
  }

  /// Text of UTF-8 (with or without BOM) or UTF-16 with BOM, as Notepad
  /// saves it. `null` for anything else
  static String? decodeText(Uint8List bytes) {
    try {
      final text = switch (bytes) {
        [0xFF, 0xFE, ...] => _decodeUtf16(bytes.sublist(2), Endian.little),
        [0xFE, 0xFF, ...] => _decodeUtf16(bytes.sublist(2), Endian.big),
        [0xEF, 0xBB, 0xBF, ...] => utf8.decode(bytes.sublist(3)),
        _ => utf8.decode(bytes),
      };

      return text == null || _binaryPattern.hasMatch(text) ? null : text;
    } on FormatException {
      return null;
    }
  }

  static String? _decodeUtf16(Uint8List bytes, Endian endianness) {
    if (bytes.length.isOdd) return null;

    final data = ByteData.sublistView(bytes);

    return String.fromCharCodes([
      for (var offset = 0; offset < bytes.length; offset += 2)
        data.getUint16(offset, endianness),
    ]);
  }
}
