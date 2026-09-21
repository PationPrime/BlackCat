import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:black_cat/src/app/design_system/design_system.dart';
import 'package:black_cat/src/app/localization/lang/locale_keys.g.dart';

/// Thanks to the user and why the support matters
class DonationsHero extends StatelessWidget {
  static const _iconSize = 56.0;

  const DonationsHero({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.color.accent.withValues(alpha: 0.35)),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          context.color.accent.withValues(alpha: 0.22),
          context.color.accent.withValues(alpha: 0.04),
        ],
      ),
    ),
    child: Row(
      children: [
        Container(
          width: _iconSize,
          height: _iconSize,
          decoration: BoxDecoration(
            color: context.color.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: context.color.accent.withValues(alpha: 0.35),
                blurRadius: 20,
              ),
            ],
          ),
          child: Icon(
            Icons.favorite_rounded,
            size: 28,
            color: context.color.onAccent,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LocaleKeys.app_donations_hero_title.tr(),
                style: context.text.header5Semibold,
              ),
              const SizedBox(height: 6),
              Text(
                LocaleKeys.app_donations_hero_description.tr(),
                style: context.text.captionRegular.copyWith(
                  color: context.color.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
