import 'package:equatable/equatable.dart';

/// A TikTok video link. A short link (`vm.tiktok.com/…`) names no video
/// until TikTok redirects it to the video page
class TikTokVideoLink extends Equatable {
  /// `null` for a short link
  final String? id;

  /// Author name of the page link, without `@`
  final String? author;

  /// The short link as given
  final Uri? shortLink;

  /// A photo post: TikTok has no video for it
  final bool isPhoto;

  const TikTokVideoLink(this.id, {this.author, this.isPhoto = false})
    : shortLink = null;

  const TikTokVideoLink.short(Uri this.shortLink)
    : id = null,
      author = null,
      isPhoto = false;

  bool get isShort => id == null;

  /// Video page without tracking parameters. TikTok opens a video page
  /// by its id alone: `@_` stands for an unknown author
  String get url => switch (id) {
    final id? =>
      'https://www.tiktok.com/@${author ?? '_'}/${isPhoto ? 'photo' : 'video'}/$id',
    null => shortLink.toString(),
  };

  @override
  List<Object?> get props => [id, author, shortLink, isPhoto];
}

abstract final class TikTokUrlParser {
  static final _idPattern = RegExp(r'^\d{8,24}$');

  /// `/@author/video/<id>` and `/@author/photo/<id>`
  static final _pagePattern = RegExp(r'^/@([^/]*)/(video|photo)/([^/]+)/?$');

  /// Mobile, embedded and player links: the id goes last
  static final _idPathPattern = RegExp(
    r'^/(?:v|embed/v2|embed|player/v1)/(\d{8,24})(?:\.html)?/?$',
  );

  /// `tiktok.com/t/<code>`
  static final _shortPathPattern = RegExp(r'^/t/[\w-]+/?$');

  static const _hosts = {'tiktok.com', 'www.tiktok.com', 'm.tiktok.com'};
  static const _shortHosts = {'vm.tiktok.com', 'vt.tiktok.com'};

  /// A short link keeps only its code: parameters are tracking
  static Uri _withoutQuery(Uri url) =>
      Uri(scheme: 'https', host: url.host.toLowerCase(), path: url.path);

  /// Video from a page, mobile, embedded or short link. `null` if this is
  /// not a TikTok video link
  static TikTokVideoLink? parse(String? input) {
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

    if (_shortHosts.contains(host)) {
      return RegExp(r'^/[\w-]+/?$').hasMatch(url.path)
          ? TikTokVideoLink.short(_withoutQuery(url))
          : null;
    }

    if (!_hosts.contains(host)) {
      return null;
    }

    if (_shortPathPattern.hasMatch(url.path)) {
      return TikTokVideoLink.short(_withoutQuery(url));
    }

    if (_pagePattern.firstMatch(url.path) case final match?) {
      final id = match.group(3)!;
      final author = match.group(1)!;

      return _idPattern.hasMatch(id)
          ? TikTokVideoLink(
              id,
              author: author.isEmpty || author == '_' ? null : author,
              isPhoto: match.group(2) == 'photo',
            )
          : null;
    }

    if (_idPathPattern.firstMatch(url.path) case final match?) {
      return TikTokVideoLink(match.group(1)!);
    }

    return null;
  }
}
