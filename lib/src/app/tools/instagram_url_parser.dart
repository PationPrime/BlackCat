import 'package:equatable/equatable.dart';

/// How an Instagram link names a post
enum InstagramPostKind {
  /// `/p/<code>`: a post of any kind
  post('p'),

  /// `/reel/<code>`
  reel('reel'),

  /// `/tv/<code>`: an old IGTV video
  tv('tv');

  final String path;

  const InstagramPostKind(this.path);
}

/// An Instagram post link. A share link (`/share/…`) names no post until
/// Instagram redirects it to the post page
class InstagramVideoLink extends Equatable {
  /// Shortcode of the post: `DZT71H-BJuK`. `null` for a share link
  final String? code;
  final InstagramPostKind kind;

  /// The share link as given
  final Uri? shareLink;

  const InstagramVideoLink(this.code, {this.kind = InstagramPostKind.post})
    : shareLink = null;

  const InstagramVideoLink.share(Uri this.shareLink)
    : code = null,
      kind = InstagramPostKind.post;

  bool get isShare => code == null;

  /// Post page without tracking parameters
  String get url => switch (code) {
    final code? => 'https://www.instagram.com/${kind.path}/$code/',
    null => shareLink.toString(),
  };

  @override
  List<Object?> get props => [code, kind, shareLink];
}

abstract final class InstagramUrlParser {
  /// `/reel/<code>`, `/p/<code>`, `/tv/<code>`, also after the author name:
  /// `/<author>/reel/<code>`. `/reels/<code>` opens the same reel
  static final _postPattern = RegExp(
    r'^/(?:[\w.]+/)?(p|reels?|tv)/([\w-]{5,})/?$',
  );

  /// `/share/<token>`, `/share/reel/<token>`, `/share/p/<token>`
  static final _sharePattern = RegExp(r'^/share/(?:(?:reel|p)/)?[\w-]+/?$');

  static const _hosts = {
    'instagram.com',
    'www.instagram.com',
    'm.instagram.com',
    'instagr.am',
    'www.instagr.am',
  };

  /// Post from a page or share link. `null` if this is not an Instagram
  /// post link: profiles, stories and audio pages are not posts
  static InstagramVideoLink? parse(String? input) {
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

    if (_sharePattern.hasMatch(url.path)) {
      /// Parameters of a share link are tracking
      return InstagramVideoLink.share(
        Uri(scheme: 'https', host: 'www.instagram.com', path: url.path),
      );
    }

    final match = _postPattern.firstMatch(url.path);

    if (match == null) return null;

    return InstagramVideoLink(
      match.group(2)!,
      kind: switch (match.group(1)!) {
        'reel' || 'reels' => InstagramPostKind.reel,
        'tv' => InstagramPostKind.tv,
        _ => InstagramPostKind.post,
      },
    );
  }
}
