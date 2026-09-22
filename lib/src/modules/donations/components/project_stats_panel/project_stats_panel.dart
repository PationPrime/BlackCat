import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:black_cat/src/app/design_system/design_system.dart';
import 'package:black_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/tools/tools.dart';
import 'package:black_cat/src/app/widgets/widgets.dart';
import 'package:black_cat/src/generated/assets/assets.gen.dart';

/// BlackCat on GitHub: the stars, which open the repository, and downloads
/// of the latest release for macOS and Windows. A number GitHub did not tell
/// is a dash
class ProjectStatsPanel extends StatelessWidget {
  static const _wideLayoutBreakpoint = 560.0;
  static const _spacing = 12.0;

  final ProjectStatsModel? stats;
  final VoidCallback? onStarsPressed;

  const ProjectStatsPanel({super.key, this.stats, this.onStarsPressed});

  Widget _platformLogo(BuildContext context, SvgGenImage logo) => logo.svg(
    width: 20,
    height: 20,
    colorFilter: ColorFilter.mode(context.color.iconPrimary, BlendMode.srcIn),
  );

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _ProjectStatTile(
        icon: Icon(Icons.star_rounded, size: 22, color: context.color.accent),
        value: AppFormatters.count(stats?.stars),
        label: LocaleKeys.app_donations_github_stars.tr(),
        tooltip: LocaleKeys.app_donations_github_open_repository.tr(),
        onPressed: onStarsPressed,
      ),
      _ProjectStatTile(
        icon: _platformLogo(context, Assets.icons.iconAppleLogo),
        value: AppFormatters.count(
          stats?.downloadsOf(ReleasePlatformModel.macos),
        ),
        label: LocaleKeys.app_donations_github_downloads_macos.tr(),
      ),
      _ProjectStatTile(
        icon: _platformLogo(context, Assets.icons.iconWindowsLogo),
        value: AppFormatters.count(
          stats?.downloadsOf(ReleasePlatformModel.windows),
        ),
        label: LocaleKeys.app_donations_github_downloads_windows.tr(),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) =>
              constraints.maxWidth >= _wideLayoutBreakpoint
              /// Tiles of the row share the height
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, tile) in tiles.indexed) ...[
                        if (index > 0) const SizedBox(width: _spacing),
                        Expanded(child: tile),
                      ],
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, tile) in tiles.indexed) ...[
                      if (index > 0) const SizedBox(height: _spacing),
                      tile,
                    ],
                  ],
                ),
        ),
        if (stats?.version case final version?) ...[
          const SizedBox(height: 8),
          Text(
            LocaleKeys.app_donations_github_latest_version.tr(
              namedArgs: {'version': version},
            ),
            style: context.text.footnoteRegular.copyWith(
              color: context.color.textHint,
            ),
          ),
        ],
      ],
    );
  }
}

/// A number with its icon and caption. With [onPressed] the tile is a link
class _ProjectStatTile extends StatelessWidget {
  static const _iconBoxSize = 40.0;

  final Widget icon;

  /// `null`: not known, a dash is shown
  final String? value;
  final String label;
  final String? tooltip;
  final VoidCallback? onPressed;

  const _ProjectStatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.tooltip,
    this.onPressed,
  });

  Widget _content(BuildContext context, bool highlighted) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOut,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.color.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: highlighted
            ? context.color.accent.withValues(alpha: 0.6)
            : context.color.border,
      ),
    ),
    child: Row(
      children: [
        Container(
          width: _iconBoxSize,
          height: _iconBoxSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.color.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.color.border),
          ),
          child: icon,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value ?? '—',
                style: context.text.header5Semibold.copyWith(
                  color: value == null
                      ? context.color.textHint
                      : context.color.textPrimary,
                ),
              ),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.captionRegular.copyWith(
                  color: context.color.textTertiary,
                ),
              ),
            ],
          ),
        ),
        if (onPressed != null) ...[
          const SizedBox(width: 8),
          Icon(
            Icons.open_in_new_rounded,
            size: 16,
            color: highlighted
                ? context.color.accent
                : context.color.textTertiary,
          ),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final tile = onPressed == null
        ? _content(context, false)
        : AppPressable(onPressed: onPressed, builder: _content);

    return Semantics(
      label: '$label: ${value ?? '—'}',
      link: onPressed != null,
      excludeSemantics: onPressed == null,
      child: tooltip == null ? tile : Tooltip(message: tooltip, child: tile),
    );
  }
}
