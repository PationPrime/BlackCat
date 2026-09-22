import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peeky_cat/src/app/design_system/design_system.dart';
import 'package:peeky_cat/src/app/models/models.dart';
import 'package:peeky_cat/src/app/repositories/repositories.dart';
import 'package:peeky_cat/src/app/router/app_router.dart';
import 'package:peeky_cat/src/app/services/services.dart';
import 'package:peeky_cat/src/app/shared_controllers/shared_controllers.dart';
import 'package:peeky_cat/src/modules/downloads/controllers/controllers.dart';

import 'fake_repositories.dart';
import 'fake_services.dart';

const testQuality = QualityModel(
  id: '1080',
  kind: QualityKind.video,
  label: '1080p',
  resolution: 1080,
);

VideoInfoModel testVideo(String id) => VideoInfoModel(
  id: id,
  title: 'Видео $id',
  url: 'https://www.youtube.com/watch?v=$id',
  qualities: const [testQuality],
);

final class FakeUrlLauncher implements UrlLauncherService {
  final opened = <String>[];
  var result = true;

  @override
  Future<bool> openUrl(String url) async {
    opened.add(url);

    return result;
  }
}

/// The app with fake repositories: the whole navigation or a single page
final class TestApp {
  final FakeVideoRepository videoRepository;
  final FakeYtDlpVideoRepository ytDlpVideoRepository;
  final FakeDependenciesRepository dependenciesRepository;
  final queueRepository = FakeDownloadQueueRepository();
  final settingsRepository = FakeSettingsRepository();
  final authenticationRepository = FakeAuthenticationRepository();
  final urlLauncher = FakeUrlLauncher();
  final videoLibraryRepository = FakeVideoLibraryRepository();
  final projectStatsRepository = FakeProjectStatsRepository();
  final videoPlayerService = FakeVideoPlayerService();
  final appWindowService = FakeAppWindowService();

  final navigationController = AppNavigationController();
  late final appWindowController = AppWindowController(
    appWindowService: appWindowService,
  );
  late final authorizationController = AuthorizationController(
    authenticationRepository: authenticationRepository,
  );
  late final dependenciesController = DependenciesController(
    dependenciesRepository: dependenciesRepository,
  );
  late final settingsController = SettingsController(
    settingsRepository: settingsRepository,
  );
  late final queueController = DownloadQueueController(
    downloadQueueRepository: queueRepository,
    videoRepository: videoRepository,
    ytDlpVideoRepository: ytDlpVideoRepository,
    settingsRepository: settingsRepository,
    authorizationController: authorizationController,
  );

  TestApp({
    FakeVideoRepository? videoRepository,
    FakeYtDlpVideoRepository? ytDlpVideoRepository,
    YtDlpSetupModel setup = testReadySetup,
  }) : videoRepository =
           videoRepository ??
           FakeVideoRepository(
             infoResults: [(failure: null, data: testVideoInfo)],
           ),
       ytDlpVideoRepository =
           ytDlpVideoRepository ??
           FakeYtDlpVideoRepository(
             infoResults: [(failure: null, data: testVideoInfo)],
           ),
       dependenciesRepository = FakeDependenciesRepository(
         setupResults: [(failure: null, data: setup)],
       );

  Widget _withProviders(Widget child) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider<FileSystemService>.value(
        value: FileSystemServiceImpl(),
      ),
      RepositoryProvider<UrlLauncherService>.value(value: urlLauncher),
      RepositoryProvider<VideoRepositoryInterface>.value(
        value: videoRepository,
      ),
      RepositoryProvider<YtDlpVideoRepositoryInterface>.value(
        value: ytDlpVideoRepository,
      ),
      RepositoryProvider<VideoLibraryRepositoryInterface>.value(
        value: videoLibraryRepository,
      ),
      RepositoryProvider<ProjectStatsRepositoryInterface>.value(
        value: projectStatsRepository,
      ),
      RepositoryProvider<VideoPlayerService>.value(value: videoPlayerService),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider<AppNavigationController>.value(
          value: navigationController,
        ),
        BlocProvider<AppWindowController>.value(value: appWindowController),
        BlocProvider<AuthorizationController>.value(
          value: authorizationController,
        ),
        BlocProvider<DependenciesController>.value(
          value: dependenciesController,
        ),
        BlocProvider<SettingsController>.value(value: settingsController),
        BlocProvider<DownloadQueueController>.value(value: queueController),
      ],
      child: child,
    ),
  );

  void _setSize(WidgetTester tester, Size size) {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// All pages with the navigation bar and the footer, on the real router
  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(1200, 900),
  }) async {
    _setSize(tester, size);
    await settingsController.loadSettings();
    await tester.pumpWidget(
      _withProviders(
        MaterialApp.router(
          theme: AppThemeData.darkTheme,
          routerConfig: AppRouter().config(),
        ),
      ),
    );
    await settle(tester);
  }

  /// One page without the navigation
  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(1000, 1800),
  }) async {
    _setSize(tester, size);
    await authorizationController.checkAuthorization();
    await settingsController.loadSettings();
    await tester.pumpWidget(
      _withProviders(
        MaterialApp(
          theme: AppThemeData.darkTheme,
          home: Builder(
            builder: (context) => switch (page) {
              final AutoRouteWrapper wrapper => wrapper.wrappedRoute(context),
              _ => page,
            },
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> addTask(WidgetTester tester, String id) async {
    await queueController.addTask(video: testVideo(id), quality: testQuality);
    await settle(tester);
  }

  /// Enough for the queue change chain, page and dialog animations
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> close() async {
    await queueController.close();
    await dependenciesController.close();
    await settingsController.close();
    await navigationController.close();
    await appWindowController.close();
  }
}
