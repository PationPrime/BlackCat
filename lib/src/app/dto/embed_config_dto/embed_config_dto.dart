import 'dart:convert';

import '../../constants/constants.dart';

/// Embedded player settings (`ytcfg`): the player API request is built from them
class EmbedConfigDto {
  static final _ytcfgSetPattern = RegExp(r'ytcfg\.set\s*\(\s*(\{.+?\})\s*\)\s*;');
  static final _playerIdPattern = RegExp(r'/s/player/([0-9a-zA-Z_-]{8})/');

  final Map<String, dynamic> ytcfg;
  final String playerId;

  const EmbedConfigDto({required this.ytcfg, required this.playerId});

  /// `null` if the page has no settings or player version
  static EmbedConfigDto? fromHtml(String html) {
    final ytcfg = parseYtcfg(html);
    final playerId = _playerIdPattern.firstMatch(html)?.group(1);

    if (ytcfg.isEmpty || playerId == null) {
      return null;
    }

    return EmbedConfigDto(ytcfg: ytcfg, playerId: playerId);
  }

  /// Merges all `ytcfg.set({...});` calls of a YouTube page
  static Map<String, dynamic> parseYtcfg(String html) {
    final ytcfg = <String, dynamic>{};

    for (final match in _ytcfgSetPattern.allMatches(html)) {
      try {
        ytcfg.addAll(jsonDecode(match.group(1)!) as Map<String, dynamic>);
      } on FormatException {
        /// Not every match is a complete object
      }
    }

    return ytcfg;
  }

  Map<String, dynamic> get context => {
    ...?(ytcfg['INNERTUBE_CONTEXT'] as Map<String, dynamic>?),
    'thirdParty': {'embedUrl': YouTubeConstants.embedUrl},
  };

  String get clientName => '${ytcfg['INNERTUBE_CONTEXT_CLIENT_NAME'] ?? 56}';

  String get clientVersion =>
      ytcfg['INNERTUBE_CLIENT_VERSION'] as String? ?? '2.20260708.00.00';

  String? get visitorData => ytcfg['VISITOR_DATA'] as String?;

  bool get loggedIn => ytcfg['LOGGED_IN'] == true;

  int? get sessionIndex => int.tryParse('${ytcfg['SESSION_INDEX'] ?? ''}');

  String? get userSessionId => ytcfg['USER_SESSION_ID'] as String?;

  String? get delegatedSessionId => ytcfg['DELEGATED_SESSION_ID'] as String?;

  Object? get encryptedHostFlags =>
      ((ytcfg['WEB_PLAYER_CONTEXT_CONFIGS']
              as Map?)?['WEB_PLAYER_CONTEXT_CONFIG_ID_EMBEDDED_PLAYER']
          as Map?)?['encryptedHostFlags'];
}
