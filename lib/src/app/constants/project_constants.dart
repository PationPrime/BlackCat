/// PeekyCat on GitHub: the repository and its releases
abstract final class ProjectConstants {
  static const repositoryUrl = 'https://github.com/PationPrime/PeekyCat';
  static const repositoryApiUrl =
      'https://api.github.com/repos/PationPrime/PeekyCat';

  /// GitHub answers 60 requests an hour without an account: the stars and
  /// downloads are asked again only after this long
  static const statsLifetime = Duration(minutes: 15);
}
