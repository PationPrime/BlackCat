import 'package:equatable/equatable.dart';

/// A link to an X (Twitter) post
class XPostLink extends Equatable {
  /// Post id: `2102042791807263094`
  final String id;

  /// Author name in links, without `@`. `null` for `/i/status/…` links
  final String? author;

  /// Media of the post the link names: `/video/2` is its second media.
  /// `null` for the post as a whole
  final int? mediaIndex;

  const XPostLink(this.id, {this.author, this.mediaIndex});

  /// Post page without tracking parameters
  String get url =>
      'https://x.com/${author ?? 'i'}/status/$id'
      '${mediaIndex == null ? '' : '/video/$mediaIndex'}';

  @override
  List<Object?> get props => [id, author, mediaIndex];
}

abstract final class XUrlParser {
  /// `/<author>/status/<id>`, `/i/status/<id>`, `/i/web/status/<id>`,
  /// with `/video/<n>` or `/photo/<n>` after them
  static final _postPattern = RegExp(
    r'^/(?:(\w{1,15})|i(?:/web)?)/status(?:es)?/(\d{1,20})'
    r'(?:/(?:video|photo)/([1-9]))?/?$',
  );

  static const _hosts = {
    'x.com',
    'www.x.com',
    'mobile.x.com',
    'twitter.com',
    'www.twitter.com',
    'mobile.twitter.com',
    'm.twitter.com',
  };

  /// Post from a link. `null` if this is not an X post link: profiles,
  /// lists and search are not posts
  static XPostLink? parse(String? input) {
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

    final match = _postPattern.firstMatch(url.path);

    if (match == null) return null;

    final author = match.group(1);

    return XPostLink(
      match.group(2)!,
      author: author == 'i' ? null : author,
      mediaIndex: int.tryParse(match.group(3) ?? ''),
    );
  }
}
