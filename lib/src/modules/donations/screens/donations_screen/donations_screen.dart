import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:black_cat/src/app/constants/constants.dart';
import 'package:black_cat/src/app/design_system/design_system.dart';
import 'package:black_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/services/services.dart';
import 'package:black_cat/src/app/widgets/widgets.dart';

import '../../components/components.dart';

/// Ways to support the developer: the same services as in rconite
@RoutePage()
class DonationsScreen extends StatefulWidget {
  const DonationsScreen({super.key});

  @override
  State<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen> {
  static const _contentMaxWidth = 920.0;
  static const _wideLayoutBreakpoint = 640.0;
  static const _cardSpacing = 16.0;

  /// Gap between the window title bar and the page header
  static const _minTopGap = 24.0;

  /// A link the system could not open
  String? _failedUrl;

  Future<void> _open(DonationPlatformModel platform) async {
    final opened = await context.read<UrlLauncherService>().openUrl(
      platform.url,
    );

    if (!mounted) return;

    setState(() => _failedUrl = opened ? null : platform.url);
  }

  void _copy(DonationPlatformModel platform) =>
      Clipboard.setData(ClipboardData(text: platform.url));

  String _descriptionOf(DonationPlatformModel platform) =>
      switch (platform.kind) {
        DonationPlatformKind.donationAlerts =>
          LocaleKeys.app_donations_platforms_donation_alerts.tr(),
        DonationPlatformKind.donatePay =>
          LocaleKeys.app_donations_platforms_donate_pay.tr(),
        DonationPlatformKind.boosty =>
          LocaleKeys.app_donations_platforms_boosty.tr(),
      };

  /// Three cards in a row on a wide page, two or one on a narrow one.
  /// Cards of a row share the height
  Widget _platforms(BoxConstraints constraints) {
    const platforms = DonationConstants.platforms;
    final columns = constraints.maxWidth >= 760
        ? 3
        : constraints.maxWidth >= 480
        ? 2
        : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var start = 0; start < platforms.length; start += columns) ...[
          if (start > 0) const SizedBox(height: _cardSpacing),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var column = 0; column < columns; column++) ...[
                  if (column > 0) const SizedBox(width: _cardSpacing),
                  Expanded(
                    child: switch (platforms.elementAtOrNull(start + column)) {
                      final platform? => DonationPlatformCard(
                        platform: platform,
                        description: _descriptionOf(platform),
                        onOpenPressed: () => _open(platform),
                        onCopyPressed: () => _copy(platform),
                      ),
                      null => const SizedBox.shrink(),
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    body: LayoutBuilder(
      builder: (context, constraints) {
        final verticalPadding = constraints.maxWidth >= _wideLayoutBreakpoint
            ? 64.0
            : 40.0;
        final mediaPadding = MediaQuery.paddingOf(context);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,

            /// The app title bar lies over the top of the page
            math.max(verticalPadding, mediaPadding.top + _minTopGap),
            16,

            /// The download footer lies over the bottom
            verticalPadding + mediaPadding.bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppPageHeader(title: LocaleKeys.app_donations_title.tr()),
                  const SizedBox(height: 24),
                  const DonationsHero(),
                  if (_failedUrl case final url?) ...[
                    const SizedBox(height: 16),
                    AppFailureBanner(
                      message: LocaleKeys.app_donations_open_failed.tr(
                        namedArgs: {'url': url},
                      ),
                      actions: [
                        AppFailureBannerAction(
                          title: LocaleKeys.app_downloader_buttons_hide.tr(),
                          onPressed: () => setState(() => _failedUrl = null),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 32),
                  Text(
                    LocaleKeys.app_donations_platforms_title.tr().toUpperCase(),
                    style: context.text.overlineRegular,
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) => _platforms(constraints),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
