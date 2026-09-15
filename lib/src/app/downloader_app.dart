import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../modules/modules.dart';
import 'design_system/design_system.dart';
import 'downloader_app_view.dart';
import 'models/models.dart';
import 'repositories/repositories.dart';
import 'router/app_router.dart';
import 'services/services.dart';
import 'shared_controllers/shared_controllers.dart';

class DownloaderApp extends StatelessWidget {
  final AppThemeType appThemeType;
  final AppRouter appRouter;
  final FileSystemService fileSystemService;
  final AuthenticationRepositoryInterface authenticationRepository;
  final VideoRepositoryInterface videoRepository;
  final SettingsRepositoryInterface settingsRepository;
  final DownloadQueueRepositoryInterface downloadQueueRepository;
  final AuthorizationController authorizationController;
  final SettingsController settingsController;
  final AppWindowController appWindowController;
  final SystemTrayController systemTrayController;

  /// Language of the first frame: the one saved in the settings
  final AppLanguageModel initialLanguage;

  const DownloaderApp({
    super.key,
    required this.appThemeType,
    required this.appRouter,
    required this.fileSystemService,
    required this.authenticationRepository,
    required this.videoRepository,
    required this.settingsRepository,
    required this.downloadQueueRepository,
    required this.authorizationController,
    required this.settingsController,
    required this.appWindowController,
    required this.systemTrayController,
    required this.initialLanguage,
  });

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider<FileSystemService>.value(value: fileSystemService),
      RepositoryProvider<AuthenticationRepositoryInterface>.value(
        value: authenticationRepository,
      ),
      RepositoryProvider<VideoRepositoryInterface>.value(
        value: videoRepository,
      ),
      RepositoryProvider<SettingsRepositoryInterface>.value(
        value: settingsRepository,
      ),
      RepositoryProvider<DownloadQueueRepositoryInterface>.value(
        value: downloadQueueRepository,
      ),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider<AuthorizationController>.value(
          value: authorizationController,
        ),
        BlocProvider<SettingsController>.value(
          value: settingsController,
        ),
        BlocProvider<AppWindowController>.value(value: appWindowController),
        BlocProvider<SystemTrayController>.value(
          value: systemTrayController,
        ),
        BlocProvider<AppThemeController>(
          create: (context) =>
              AppThemeController(initialThemeType: appThemeType),
        ),
        BlocProvider<DownloadQueueController>(
          lazy: false,
          create: (context) => DownloadQueueController(
            downloadQueueRepository: context
                .read<DownloadQueueRepositoryInterface>(),
            videoRepository: context.read<VideoRepositoryInterface>(),
            settingsRepository: context.read<SettingsRepositoryInterface>(),
            authorizationController: context.read<AuthorizationController>(),
          )..restoreQueue(),
        ),
      ],
      child: DownloaderAppView(
        appRouter: appRouter,
        initialLanguage: initialLanguage,
      ),
    ),
  );
}
