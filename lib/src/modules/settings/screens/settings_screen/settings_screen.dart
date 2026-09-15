import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:youtube_downloader/src/app/services/services.dart';
import 'package:youtube_downloader/src/app/shared_controllers/shared_controllers.dart';
import 'package:youtube_downloader/src/app/widgets/widgets.dart';

import '../../components/components.dart';

@RoutePage()
class SettingsScreen extends StatelessWidget {
  static const _contentMaxWidth = 640.0;
  static const _wideLayoutBreakpoint = 640.0;

  /// Gap between the window title bar and the screen header
  static const _minTopGap = 24.0;

  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<SettingsController, SettingsState>(
        builder: (context, settingsState) => AppScaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final verticalPadding =
                  constraints.maxWidth >= _wideLayoutBreakpoint ? 64.0 : 40.0;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,

                  /// The app title bar lies over the top of the screen
                  math.max(
                    verticalPadding,
                    MediaQuery.paddingOf(context).top + _minTopGap,
                  ),
                  16,
                  verticalPadding,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _contentMaxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SettingsHeader(
                          onBackPressed: () => context.router.maybePop(),
                        ),
                        const SizedBox(height: 32),
                        if (settingsState.failure case final failure?) ...[
                          AppFailureBanner(message: failure.message),
                          const SizedBox(height: 16),
                        ],
                        DownloadDirectoryCard(
                          downloadDirectory: settingsState.downloadDirectory,
                          onChangePressed: context
                              .read<SettingsController>()
                              .pickDownloadDirectory,
                          onResetPressed: context
                              .read<SettingsController>()
                              .resetDownloadDirectory,
                          onOpenPressed: () => switch (settingsState
                              .downloadDirectory) {
                            final directory? => context
                                .read<FileSystemService>()
                                .openFolder(directory.path),
                            null => null,
                          },
                        ),
                        const SizedBox(height: 16),
                        LanguageCard(
                          selectedLanguage: settingsState.language,
                          onLanguageSelected: context
                              .read<SettingsController>()
                              .changeLanguage,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
}
