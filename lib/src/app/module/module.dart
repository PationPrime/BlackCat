import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_web_auth_2_platform_interface/flutter_web_auth_2_platform_interface.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:media_kit/media_kit.dart';

import '../api/api.dart';
import '../data_sources/data_sources.dart';
import '../design_system/design_system.dart';
import '../localization/lang/locale_keys.g.dart';
import '../logger/app_logger.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import '../router/app_router.dart';
import '../runner_app.dart';
import '../services/services.dart';
import '../session/session_store.dart';
import '../shared_controllers/shared_controllers.dart';
import '../storage/database/database.dart';
import '../storage/database/providers/providers.dart';

final class AppModule {
  AppModule._();

  static final instance = AppModule._();

  static const _appLogger = AppLogger(where: 'AppModule');

  static late final ApiProvider _apiProvider;
  static late final FileSystemService _fileSystemService;
  static late final DownloadTaskTableProvider _downloadTaskTableProvider;
  static late final LibraryVideoTableProvider _libraryVideoTableProvider;
  static late final AuthenticationRepositoryInterface _authenticationRepository;
  static late final VideoRepositoryInterface _videoRepository;
  static late final YtDlpVideoRepositoryInterface _ytDlpVideoRepository;
  static late final DependenciesRepositoryInterface _dependenciesRepository;
  static late final SettingsRepositoryInterface _settingsRepository;
  static late final DownloadQueueRepositoryInterface _downloadQueueRepository;
  static late final VideoLibraryRepositoryInterface _videoLibraryRepository;
  static late final VideoPlayerService _videoPlayerService;
  static late final AuthorizationController _authorizationController;
  static late final SettingsController _settingsController;
  static late final DependenciesController _dependenciesController;
  static late final AppWindowController _appWindowController;
  static late final SystemTrayController _systemTrayController;
  static late final AppRouter _appRouter;

  Future<void> initApp(List<String> args) async {
    FlutterError.onError = (details) {
      _appLogger.logError(
        'FlutterError: ${details.exception}',
        stackTrace: details.stack,
      );

      FlutterError.presentError(details);
    };

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      _appLogger.logError('PlatformError: $error', stackTrace: stackTrace);

      return false;
    };

    await runZonedGuarded(
      () async {
        await _configureDependencies();

        _apiProvider = ApiProvider();

        _fileSystemService = FileSystemServiceImpl();

        const fileSelectorService = FileSelectorServiceImpl();

        final localAuthenticationDataSource = LocalAuthenticationDataSourceImpl(
          fileSystemService: _fileSystemService,
        );

        final signInWebViewPlatform = SignInWebViewPlatform(
          profileFolder: localAuthenticationDataSource.signInProfileFolder,
          windowTitle: LocaleKeys.app_authorization_window_title.tr,
        );

        /// flutter_web_auth_2 on Windows works through this implementation
        FlutterWebAuth2Platform.instance = signInWebViewPlatform;

        _authenticationRepository = AuthenticationRepository(
          localDataSource: localAuthenticationDataSource,
          webDataSource: WebAuthenticationDataSourceImpl(
            signInWebViewPlatform: signInWebViewPlatform,
            localAuthenticationDataSource: localAuthenticationDataSource,
          ),
          fileSelectorService: fileSelectorService,
        );

        final sessionStore = SessionStore(
          localAuthenticationDataSource: localAuthenticationDataSource,
        );

        const localDownloadStateDataSource = LocalDownloadStateDataSourceImpl();

        const mediaMuxerService = Mp4MediaMuxerServiceImpl();

        /// Both Instagram engines read the files through it
        final remoteInstagramDataSource = RemoteInstagramDataSourceImpl(
          apiProvider: _apiProvider,
        );

        /// Both X engines take the file sizes from it
        final remoteXDataSource = RemoteXDataSourceImpl(
          apiProvider: _apiProvider,
        );

        /// Every site has its own repository; the link picks it
        _videoRepository = SourceVideoRepository({
          VideoSourceModel.youtube: YouTubeVideoRepository(
            remoteYouTubeDataSource: RemoteYouTubeDataSourceImpl(
              apiProvider: _apiProvider,
              sessionStore: sessionStore,
              localPlayerDataSource: LocalPlayerDataSourceImpl(
                fileSystemService: _fileSystemService,
              ),
            ),
            remoteMediaStreamDataSource: RemoteMediaStreamDataSourceImpl(
              apiProvider: _apiProvider,
            ),
            challengeSolverService: ChallengeSolverServiceImpl(
              jsEngineService: WebViewJsEngineServiceImpl(
                fileSystemService: _fileSystemService,
              ),
              loadScript: (name) => rootBundle.loadString('assets/ejs/$name'),
            ),
            mediaMuxerService: mediaMuxerService,
            fileSystemService: _fileSystemService,
            sessionStore: sessionStore,
          ),
          VideoSourceModel.rutube: RuTubeVideoRepository(
            remoteRuTubeDataSource: RemoteRuTubeDataSourceImpl(
              apiProvider: _apiProvider,
            ),
            mediaMuxerService: mediaMuxerService,
            fileSystemService: _fileSystemService,
          ),
          VideoSourceModel.tiktok: TikTokVideoRepository(
            remoteTikTokDataSource: RemoteTikTokDataSourceImpl(
              apiProvider: _apiProvider,
            ),
            fileSystemService: _fileSystemService,
          ),
          VideoSourceModel.instagram: InstagramVideoRepository(
            remoteInstagramDataSource: remoteInstagramDataSource,
            mediaMuxerService: mediaMuxerService,
            fileSystemService: _fileSystemService,
          ),
          VideoSourceModel.x: XVideoRepository(
            remoteXDataSource: remoteXDataSource,
            fileSystemService: _fileSystemService,
          ),
        });

        final ytDlpService = YtDlpServiceImpl(
          fileSystemService: _fileSystemService,
        );

        _ytDlpVideoRepository = SourceYtDlpVideoRepository({
          VideoSourceModel.youtube: YtDlpVideoRepository(
            ytDlpService: ytDlpService,
            mediaMuxerService: mediaMuxerService,
            fileSystemService: _fileSystemService,
            sessionStore: sessionStore,
            localAuthenticationDataSource: localAuthenticationDataSource,
            localDownloadStateDataSource: localDownloadStateDataSource,
          ),
          VideoSourceModel.rutube: RuTubeYtDlpVideoRepository(
            ytDlpService: ytDlpService,
            mediaMuxerService: mediaMuxerService,
            fileSystemService: _fileSystemService,
          ),
          VideoSourceModel.tiktok: TikTokYtDlpVideoRepository(
            ytDlpService: ytDlpService,
            fileSystemService: _fileSystemService,
          ),
          VideoSourceModel.instagram: InstagramYtDlpVideoRepository(
            ytDlpService: ytDlpService,
            remoteInstagramDataSource: remoteInstagramDataSource,
            mediaMuxerService: mediaMuxerService,
            fileSystemService: _fileSystemService,
          ),
          VideoSourceModel.x: XYtDlpVideoRepository(
            ytDlpService: ytDlpService,
            remoteXDataSource: remoteXDataSource,
            fileSystemService: _fileSystemService,
          ),
        });

        _dependenciesRepository = DependenciesRepository(
          ytDlpService: ytDlpService,
          remoteDependencyDataSource: RemoteDependencyDataSourceImpl(
            apiProvider: _apiProvider,
          ),
          fileSystemService: _fileSystemService,
        );

        _settingsRepository = SettingsRepository(
          localSettingsDataSource: LocalSettingsDataSourceImpl(),
          fileSelectorService: fileSelectorService,
          fileSystemService: _fileSystemService,
        );

        _downloadQueueRepository = DownloadQueueRepository(
          downloadTaskTableProvider: _downloadTaskTableProvider,
          remoteThumbnailDataSource: RemoteThumbnailDataSourceImpl(
            apiProvider: _apiProvider,
          ),
          localDownloadStateDataSource: localDownloadStateDataSource,
          fileSystemService: _fileSystemService,
        );

        _videoLibraryRepository = VideoLibraryRepository(
          libraryVideoTableProvider: _libraryVideoTableProvider,
          downloadTaskTableProvider: _downloadTaskTableProvider,
          localVideoLibraryDataSource: LocalVideoLibraryDataSourceImpl(
            fileSystemService: _fileSystemService,
          ),
          videoMetadataService: VideoMetadataServiceImpl(),
        );

        _videoPlayerService = MediaKitVideoPlayerServiceImpl();

        _authorizationController = AuthorizationController(
          authenticationRepository: _authenticationRepository,
        );

        /// The first frame is drawn in the saved language right away
        final initialLanguage =
            (await _settingsRepository.getLanguage()).data ??
            AppLanguageModel.fallback;

        _settingsController = SettingsController(
          settingsRepository: _settingsRepository,
          initialLanguage: initialLanguage,
        )..loadSettings();

        /// A missing yt-dlp is offered for installation on the main screen
        _dependenciesController = DependenciesController(
          dependenciesRepository: _dependenciesRepository,
        )..check();

        /// The app title bar and the tray icon are ready before the first frame:
        /// the window never shows the system title bar
        _appWindowController = AppWindowController(
          appWindowService: AppWindowServiceImpl(),
        );
        await _appWindowController.initialize();

        _systemTrayController = SystemTrayController(
          systemTrayService: SystemTrayServiceImpl(),
          appWindowController: _appWindowController,
        );
        await _systemTrayController.initialize();

        _appRouter = AppRouter();

        runApp(
          BlackCataRunnerApp(
            appThemeType: const AppDarkTheme(),
            appRouter: _appRouter,
            fileSystemService: _fileSystemService,
            authenticationRepository: _authenticationRepository,
            videoRepository: _videoRepository,
            ytDlpVideoRepository: _ytDlpVideoRepository,
            dependenciesRepository: _dependenciesRepository,
            settingsRepository: _settingsRepository,
            downloadQueueRepository: _downloadQueueRepository,
            videoLibraryRepository: _videoLibraryRepository,
            videoPlayerService: _videoPlayerService,
            authorizationController: _authorizationController,
            settingsController: _settingsController,
            dependenciesController: _dependenciesController,
            urlLauncherService: const UrlLauncherServiceImpl(),
            appWindowController: _appWindowController,
            systemTrayController: _systemTrayController,
            initialLanguage: initialLanguage,
          ),
        );
      },
      (error, stackTrace) {
        _appLogger.logError(
          'Internal BlackCat error: $error',
          stackTrace: stackTrace,
        );
      },
    );
  }

  Future<void> _configureDependencies() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await EasyLocalization.ensureInitialized();

      /// libmpv of the player is loaded before any video opens
      MediaKit.ensureInitialized();
      await initializeDateFormatting();
      await _initializeDriftDatabase();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        Exception('Failed to configure dependencies: $error'),
        stackTrace,
      );
    }
  }

  Future<void> _initializeDriftDatabase() async {
    final databaseIsolate = await AppDatabase.connectIsolateDatabase();

    _downloadTaskTableProvider = DownloadTaskTableProvider(
      databaseInstance: databaseIsolate.database,
    );

    _libraryVideoTableProvider = LibraryVideoTableProvider(
      databaseInstance: databaseIsolate.database,
    );
  }

  Future<void> dispose() async {
    await _authorizationController.close();
    await _settingsController.close();
    await _dependenciesController.close();
    await _systemTrayController.close();
    await _appWindowController.close();
  }
}
