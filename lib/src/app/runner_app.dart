import 'package:flutter/widgets.dart';

import 'design_system/design_system.dart';
import 'blackcat_app.dart';
import 'models/models.dart';
import 'repositories/repositories.dart';
import 'router/app_router.dart';
import 'services/services.dart';
import 'shared_controllers/shared_controllers.dart';

class BlackCataRunnerApp extends StatelessWidget {
  final AppThemeType appThemeType;
  final AppRouter appRouter;
  final FileSystemService fileSystemService;
  final UrlLauncherService urlLauncherService;
  final AuthenticationRepositoryInterface authenticationRepository;
  final VideoRepositoryInterface videoRepository;
  final YtDlpVideoRepositoryInterface ytDlpVideoRepository;
  final DependenciesRepositoryInterface dependenciesRepository;
  final SettingsRepositoryInterface settingsRepository;
  final DownloadQueueRepositoryInterface downloadQueueRepository;
  final VideoLibraryRepositoryInterface videoLibraryRepository;
  final VideoPlayerService videoPlayerService;
  final AuthorizationController authorizationController;
  final SettingsController settingsController;
  final DependenciesController dependenciesController;
  final AppWindowController appWindowController;
  final SystemTrayController systemTrayController;

  /// Language of the first frame: the one saved in the settings
  final AppLanguageModel initialLanguage;

  const BlackCataRunnerApp({
    super.key,
    required this.appThemeType,
    required this.appRouter,
    required this.fileSystemService,
    required this.urlLauncherService,
    required this.authenticationRepository,
    required this.videoRepository,
    required this.ytDlpVideoRepository,
    required this.dependenciesRepository,
    required this.settingsRepository,
    required this.downloadQueueRepository,
    required this.videoLibraryRepository,
    required this.videoPlayerService,
    required this.authorizationController,
    required this.settingsController,
    required this.dependenciesController,
    required this.appWindowController,
    required this.systemTrayController,
    required this.initialLanguage,
  });

  @override
  Widget build(BuildContext context) => BlackCatApp(
    appThemeType: appThemeType,
    appRouter: appRouter,
    fileSystemService: fileSystemService,
    urlLauncherService: urlLauncherService,
    authenticationRepository: authenticationRepository,
    videoRepository: videoRepository,
    ytDlpVideoRepository: ytDlpVideoRepository,
    dependenciesRepository: dependenciesRepository,
    settingsRepository: settingsRepository,
    downloadQueueRepository: downloadQueueRepository,
    videoLibraryRepository: videoLibraryRepository,
    videoPlayerService: videoPlayerService,
    authorizationController: authorizationController,
    settingsController: settingsController,
    dependenciesController: dependenciesController,
    appWindowController: appWindowController,
    systemTrayController: systemTrayController,
    initialLanguage: initialLanguage,
  );
}
