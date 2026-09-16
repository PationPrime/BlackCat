// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

/// generated route for
/// [AuthorizationWrapperRouterPage]
class AuthorizationWrapperRouter extends PageRouteInfo<void> {
  const AuthorizationWrapperRouter({List<PageRouteInfo>? children})
    : super(AuthorizationWrapperRouter.name, initialChildren: children);

  static const String name = 'AuthorizationWrapperRouter';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const AuthorizationWrapperRouterPage();
    },
  );
}

/// generated route for
/// [DownloaderScreen]
class DownloaderRoute extends PageRouteInfo<void> {
  const DownloaderRoute({List<PageRouteInfo>? children})
    : super(DownloaderRoute.name, initialChildren: children);

  static const String name = 'DownloaderRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const DownloaderScreen();
    },
  );
}

/// generated route for
/// [MainWrapperRouterPage]
class MainWrapperRouter extends PageRouteInfo<void> {
  const MainWrapperRouter({List<PageRouteInfo>? children})
    : super(MainWrapperRouter.name, initialChildren: children);

  static const String name = 'MainWrapperRouter';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const MainWrapperRouterPage();
    },
  );
}

/// generated route for
/// [SettingsScreen]
class SettingsRoute extends PageRouteInfo<SettingsRouteArgs> {
  SettingsRoute({
    Key? key,
    bool highlightCookies = false,
    List<PageRouteInfo>? children,
  }) : super(
         SettingsRoute.name,
         args: SettingsRouteArgs(key: key, highlightCookies: highlightCookies),
         initialChildren: children,
       );

  static const String name = 'SettingsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SettingsRouteArgs>(
        orElse: () => const SettingsRouteArgs(),
      );
      return WrappedRoute(
        child: SettingsScreen(
          key: args.key,
          highlightCookies: args.highlightCookies,
        ),
      );
    },
  );
}

class SettingsRouteArgs {
  const SettingsRouteArgs({this.key, this.highlightCookies = false});

  final Key? key;

  final bool highlightCookies;

  @override
  String toString() {
    return 'SettingsRouteArgs{key: $key, highlightCookies: $highlightCookies}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SettingsRouteArgs) return false;
    return key == other.key && highlightCookies == other.highlightCookies;
  }

  @override
  int get hashCode => key.hashCode ^ highlightCookies.hashCode;
}
