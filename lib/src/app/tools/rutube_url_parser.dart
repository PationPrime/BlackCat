import 'package:equatable/equatable.dart';

/// Canonical RuTube video link
class RuTubeVideoLink extends Equatable {
  final String id;

  /// Key of a private video: its link works only with it
  final String? privateKey;

  /// A vertical short video: its page is `/shorts/`
  final bool isShorts;

  const RuTubeVideoLink(this.id, {this.privateKey, this.isShorts = false});

  /// Video page without playlist and tracking parameters
  String get url => switch (privateKey) {
    final key? => 'https://rutube.ru/video/private/$id/?p=$key',
    null when isShorts => 'https://rutube.ru/shorts/$id/',
    null => 'https://rutube.ru/video/$id/',
  };

  @override
  List<Object?> get props => [id, privateKey, isShorts];
}

abstract final class RuTubeUrlParser {
  static final _idPattern = RegExp(r'^[0-9a-f]{32}$');

  /// Paths of a video: page, private page, short, player; the id goes last
  static final _pathPattern = RegExp(
    r'^/(?:video/private|video|shorts|play/embed|embed|live/video)/([^/]+)/?$',
  );

  static const _hosts = {'rutube.ru', 'www.rutube.ru', 'm.rutube.ru'};

  /// Video from a page, short, private or player link. `null` if this is
  /// not a RuTube video link
  static RuTubeVideoLink? parse(String? input) {
    final Uri url;

    try {
      url = Uri.parse((input ?? '').trim());
    } on FormatException {
      return null;
    }

    if ((url.scheme != 'https' && url.scheme != 'http') ||
        !_hosts.contains(url.host.toLowerCase())) {
      return null;
    }

    final match = _pathPattern.firstMatch(url.path);
    final id = match?.group(1)?.toLowerCase();

    if (match == null || id == null || !_idPattern.hasMatch(id)) {
      return null;
    }

    String? privateKey;

    try {
      final key = url.queryParameters['p']?.trim();
      privateKey = key == null || key.isEmpty ? null : key;
    } on FormatException {
      /// Broken percent-encoding in the parameters
      return null;
    }

    return RuTubeVideoLink(
      id,
      privateKey: privateKey,
      isShorts: url.path.startsWith('/shorts/'),
    );
  }
}
