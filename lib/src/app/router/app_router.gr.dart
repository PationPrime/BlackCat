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
/// [DonationsScreen]
class DonationsRoute extends PageRouteInfo<void> {
  const DonationsRoute({List<PageRouteInfo>? children})
    : super(DonationsRoute.name, initialChildren: children);

  static const String name = 'DonationsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const DonationsScreen();
    },
  );
}

/// generated route for
/// [DownloadsScreen]
class DownloadsRoute extends PageRouteInfo<void> {
  const DownloadsRoute({List<PageRouteInfo>? children})
    : super(DownloadsRoute.name, initialChildren: children);

  static const String name = 'DownloadsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const DownloadsScreen();
    },
  );
}

/// generated route for
/// [HomeScreen]
class HomeRoute extends PageRouteInfo<void> {
  const HomeRoute({List<PageRouteInfo>? children})
    : super(HomeRoute.name, initialChildren: children);

  static const String name = 'HomeRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return WrappedRoute(child: const HomeScreen());
    },
  );
}

/// generated route for
/// [HomeStackScreen]
class HomeStackRoute extends PageRouteInfo<void> {
  const HomeStackRoute({List<PageRouteInfo>? children})
    : super(HomeStackRoute.name, initialChildren: children);

  static const String name = 'HomeStackRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const HomeStackScreen();
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
/// [PlayerScreen]
class PlayerRoute extends PageRouteInfo<void> {
  const PlayerRoute({List<PageRouteInfo>? children})
    : super(PlayerRoute.name, initialChildren: children);

  static const String name = 'PlayerRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return WrappedRoute(child: const PlayerScreen());
    },
  );
}

/// generated route for
/// [SettingsScreen]
class SettingsRoute extends PageRouteInfo<void> {
  const SettingsRoute({List<PageRouteInfo>? children})
    : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return WrappedRoute(child: const SettingsScreen());
    },
  );
}
