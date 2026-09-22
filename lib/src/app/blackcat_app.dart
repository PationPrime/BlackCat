import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../modules/modules.dart';
import 'design_system/design_system.dart';
import 'backcat_app_view.dart';
import 'models/models.dart';
import 'repositories/repositories.dart';
import 'router/app_router.dart';
import 'services/services.dart';
import 'shared_controllers/shared_controllers.dart';

class BlackCatApp extends StatelessWidget {
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
  final ProjectStatsRepositoryInterface projectStatsRepository;
  final VideoPlayerService videoPlayerService;
  final AuthorizationController authorizationController;
  final SettingsController settingsController;
  final DependenciesController dependenciesController;
  final AppWindowController appWindowController;
  final SystemTrayController systemTrayController;

  /// Language of the first frame: the one saved in the settings
  final AppLanguageModel initialLanguage;

  const BlackCatApp({
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
    required this.projectStatsRepository,
    required this.videoPlayerService,
    required this.authorizationController,
    required this.settingsController,
    required this.dependenciesController,
    required this.appWindowController,
    required this.systemTrayController,
    required this.initialLanguage,
  });

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider<FileSystemService>.value(value: fileSystemService),
      RepositoryProvider<UrlLauncherService>.value(value: urlLauncherService),
      RepositoryProvider<AuthenticationRepositoryInterface>.value(
        value: authenticationRepository,
      ),
      RepositoryProvider<VideoRepositoryInterface>.value(
        value: videoRepository,
      ),
      RepositoryProvider<YtDlpVideoRepositoryInterface>.value(
        value: ytDlpVideoRepository,
      ),
      RepositoryProvider<DependenciesRepositoryInterface>.value(
        value: dependenciesRepository,
      ),
      RepositoryProvider<SettingsRepositoryInterface>.value(
        value: settingsRepository,
      ),
      RepositoryProvider<DownloadQueueRepositoryInterface>.value(
        value: downloadQueueRepository,
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
        BlocProvider<AuthorizationController>.value(
          value: authorizationController,
        ),
        BlocProvider<SettingsController>.value(value: settingsController),
        BlocProvider<AppWindowController>.value(value: appWindowController),
        BlocProvider<DependenciesController>.value(
          value: dependenciesController,
        ),
        BlocProvider<SystemTrayController>.value(value: systemTrayController),
        BlocProvider<AppThemeController>(
          create: (context) =>
              AppThemeController(initialThemeType: appThemeType),
        ),
        BlocProvider<AppNavigationController>(
          create: (context) => AppNavigationController(),
        ),
        BlocProvider<DownloadQueueController>(
          lazy: false,
          create: (context) => DownloadQueueController(
            downloadQueueRepository: context
                .read<DownloadQueueRepositoryInterface>(),
            videoRepository: context.read<VideoRepositoryInterface>(),
            ytDlpVideoRepository: context.read<YtDlpVideoRepositoryInterface>(),
            settingsRepository: context.read<SettingsRepositoryInterface>(),
            authorizationController: context.read<AuthorizationController>(),
          )..restoreQueue(),
        ),
      ],
      child: BlackCatAppView(
        appRouter: appRouter,
        initialLanguage: initialLanguage,
      ),
    ),
  );
}
