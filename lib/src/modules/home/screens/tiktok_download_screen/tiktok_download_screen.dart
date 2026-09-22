import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:black_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/repositories/repositories.dart';
import 'package:black_cat/src/app/shared_controllers/shared_controllers.dart';

import '../../components/components.dart';
import '../../controllers/controllers.dart';

/// TikTok videos by link, full ones and short ones. TikTok needs no account:
/// the videos it shows are downloaded as they are
@RoutePage()
class TikTokDownloadScreen extends StatelessWidget implements AutoRouteWrapper {
  const TikTokDownloadScreen({super.key});

  @override
  Widget wrappedRoute(BuildContext context) => BlocProvider<AddVideoController>(
    create: (context) => AddVideoController(
      videoRepository: context.read<VideoRepositoryInterface>(),
      ytDlpVideoRepository: context.read<YtDlpVideoRepositoryInterface>(),
      authorizationController: context.read<AuthorizationController>(),
      source: VideoSourceModel.tiktok,
    ),
    child: this,
  );

  @override
  Widget build(BuildContext context) => VideoSearchView(
    title: LocaleKeys.app_home_tiktok_title.tr(),
    subtitle: LocaleKeys.app_home_tiktok_subtitle.tr(),
    urlHint: LocaleKeys.app_home_tiktok_url_hint.tr(),
  );
}
