import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:peeky_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:peeky_cat/src/app/models/models.dart';
import 'package:peeky_cat/src/app/repositories/repositories.dart';
import 'package:peeky_cat/src/app/shared_controllers/shared_controllers.dart';

import '../../components/components.dart';
import '../../controllers/controllers.dart';

/// Instagram reels and video posts by link. Only what Instagram shows
/// without an account is downloaded
@RoutePage()
class InstagramDownloadScreen extends StatelessWidget
    implements AutoRouteWrapper {
  const InstagramDownloadScreen({super.key});

  @override
  Widget wrappedRoute(BuildContext context) => BlocProvider<AddVideoController>(
    create: (context) => AddVideoController(
      videoRepository: context.read<VideoRepositoryInterface>(),
      ytDlpVideoRepository: context.read<YtDlpVideoRepositoryInterface>(),
      authorizationController: context.read<AuthorizationController>(),
      source: VideoSourceModel.instagram,
    ),
    child: this,
  );

  @override
  Widget build(BuildContext context) => VideoSearchView(
    title: LocaleKeys.app_home_instagram_title.tr(),
    subtitle: LocaleKeys.app_home_instagram_subtitle.tr(),
    urlHint: LocaleKeys.app_home_instagram_url_hint.tr(),
  );
}
