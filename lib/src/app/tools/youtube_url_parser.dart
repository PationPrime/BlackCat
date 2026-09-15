import 'package:equatable/equatable.dart';

/// Ссылка на видео YouTube в каноническом виде
class YouTubeVideoLink extends Equatable {
  final String id;

  const YouTubeVideoLink(this.id);

  /// Страница видео без меток отслеживания и плейлиста
  String get url => 'https://www.youtube.com/watch?v=$id';

  @override
  List<Object?> get props => [id];
}

abstract final class YouTubeUrlParser {
  static final _videoIdPattern = RegExp(r'^[\w-]{11}$');
  static final _pathIdPattern = RegExp(r'^/(?:shorts|embed|live|v)/([^/]+)');

  static const _youtubeHosts = {
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtube-nocookie.com',
    'www.youtube-nocookie.com',
  };

  /// Номер видео из любой обычной ссылки: watch, youtu.be, shorts, embed, live.
  /// `null`, если это не ссылка на видео YouTube
  static YouTubeVideoLink? parse(String? input) {
    final Uri url;

    try {
      url = Uri.parse((input ?? '').trim());
    } on FormatException {
      return null;
    }

    if (url.scheme != 'https' && url.scheme != 'http') {
      return null;
    }

    final host = url.host.toLowerCase();
    String? id;

    try {
      if (host == 'youtu.be') {
        final segments = url.path.split('/');
        id = segments.length > 1 ? segments[1] : null;
      } else if (_youtubeHosts.contains(host)) {
        id = url.path == '/watch'
            ? url.queryParameters['v']
            : _pathIdPattern.firstMatch(url.path)?.group(1);
      }
    } on FormatException {
      /// Сломанная процентная кодировка в параметрах
      return null;
    }

    if (id == null || !_videoIdPattern.hasMatch(id)) {
      return null;
    }

    return YouTubeVideoLink(id);
  }
}
