import 'dart:io';

import '../constants/constants.dart';
import '../data_sources/authentication/local_authentication_data_source.dart';
import '../models/models.dart';
import '../tools/tools.dart';

/// youtube.com cookies of the signed-in account for YouTube requests.
/// Cookies that YouTube updates in responses are written back to the file
final class SessionStore {
  final LocalAuthenticationDataSource _localAuthenticationDataSource;

  List<BrowserCookieModel> _cookies = const [];

  SessionStore({required this._localAuthenticationDataSource});

  bool get signedIn => _cookies.any((cookie) => cookie.name == 'LOGIN_INFO');

  /// Re-reads the file: the user may have signed in or out since the last request
  Future<void> reload() async {
    final cookies = await _localAuthenticationDataSource.readCookies();

    _cookies =
        cookies
            ?.where((cookie) => NetscapeCookies.isYouTube(cookie.domain))
            .toList() ??
        const [];
  }

  /// `Cookie` header for youtube.com; `null` when signed out
  String? get cookieHeader {
    final now = DateTime.now();
    final live = _cookies.where(
      (cookie) => cookie.expires == null || cookie.expires!.isAfter(now),
    );

    return live.isEmpty
        ? null
        : live.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');
  }

  /// Headers the YouTube web client sends with requests on behalf of the account
  Map<String, String> authHeaders({
    String? userSessionId,
    int? sessionIndex,
    bool loggedIn = false,
  }) {
    final cookie = cookieHeader;

    if (cookie == null) {
      return const {};
    }

    final authorization = SapisidAuthorization.build(
      sapisid: _value('SAPISID'),
      sapisid1p: _value('__Secure-1PAPISID'),
      sapisid3p: _value('__Secure-3PAPISID'),
      userSessionId: userSessionId,
    );

    return {
      'Cookie': cookie,
      'X-Goog-AuthUser': '${sessionIndex ?? 0}',
      if (authorization != null) ...{
        'Authorization': authorization,
        'X-Origin': YouTubeConstants.origin,
      },
      if (loggedIn) 'X-Youtube-Bootstrap-Logged-In': 'true',
    };
  }

  /// Applies `Set-Cookie` of a youtube.com response and saves the file if anything changed
  Future<void> update(List<String>? setCookieHeaders) async {
    if (setCookieHeaders == null ||
        setCookieHeaders.isEmpty ||
        _cookies.isEmpty) {
      return;
    }

    var changed = false;
    final cookies = [..._cookies];

    for (final header in setCookieHeaders) {
      final Cookie parsed;

      try {
        parsed = Cookie.fromSetCookieValue(header);
      } on FormatException {
        continue;
      }

      final domain = parsed.domain == null
          ? '.youtube.com'
          : (parsed.domain!.startsWith('.')
                ? parsed.domain!
                : '.${parsed.domain}');

      if (!NetscapeCookies.isYouTube(domain)) {
        continue;
      }

      final index = cookies.indexWhere(
        (cookie) => cookie.name == parsed.name && cookie.domain == domain,
      );
      final expires = parsed.maxAge != null
          ? DateTime.now().add(Duration(seconds: parsed.maxAge!))
          : parsed.expires;
      final updated = BrowserCookieModel(
        name: parsed.name,
        value: parsed.value,
        domain: domain,
        path: parsed.path ?? '/',
        expires: expires,
        secure: parsed.secure,
        httpOnly: parsed.httpOnly,
        sessionOnly: expires == null,
      );

      if (index == -1) {
        cookies.add(updated);
      } else if (cookies[index].value != updated.value) {
        cookies[index] = updated;
      } else {
        continue;
      }

      changed = true;
    }

    if (!changed) {
      return;
    }

    _cookies = cookies;

    /// Google cookies saved by the sign-in window stay as they were
    final others =
        (await _localAuthenticationDataSource.readCookies())?.where(
          (cookie) => !NetscapeCookies.isYouTube(cookie.domain),
        ) ??
        const <BrowserCookieModel>[];

    await _localAuthenticationDataSource.writeCookies([...others, ...cookies]);
  }

  String? _value(String name) {
    for (final cookie in _cookies) {
      if (cookie.name == name && cookie.value.isNotEmpty) {
        return cookie.value;
      }
    }

    return null;
  }
}
