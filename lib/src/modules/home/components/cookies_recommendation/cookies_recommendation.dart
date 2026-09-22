import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:black_cat/src/app/design_system/design_system.dart';
import 'package:black_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:black_cat/src/app/widgets/widgets.dart';

/// Recommends cookies over the Google sign-in window, until the account
/// uses imported cookies
class CookiesRecommendation extends StatelessWidget {
  /// Signed in through the Google window: the notice offers to replace it
  final bool signedInWithGoogle;
  final VoidCallback? onAddCookiesPressed;

  /// Why cookies: the explanation with the Google sign-in still at hand
  final VoidCallback? onWhyPressed;

  const CookiesRecommendation({
    super.key,
    this.signedInWithGoogle = false,
    this.onAddCookiesPressed,
    this.onWhyPressed,
  });

  @override
  Widget build(BuildContext context) => AppBorderedBox(
    padding: const EdgeInsets.all(16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.cookie_outlined, size: 20, color: context.color.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LocaleKeys.app_authorization_recommendation_title.tr(),
                style: context.text.captionMedium.copyWith(
                  color: context.color.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                signedInWithGoogle
                    ? LocaleKeys.app_authorization_recommendation_window.tr()
                    : LocaleKeys.app_authorization_recommendation_signed_out
                          .tr(),
                style: context.text.captionRegular.copyWith(
                  color: context.color.textTertiary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppSecondaryButton(
                    title: signedInWithGoogle
                        ? LocaleKeys.app_authorization_recommendation_replace
                              .tr()
                        : LocaleKeys.app_authorization_add_cookies.tr(),
                    onPressed: onAddCookiesPressed,
                    compact: true,
                  ),
                  AppLinkButton(
                    title: LocaleKeys.app_authorization_recommendation_why.tr(),
                    titleColor: context.color.textSecondary,
                    onPressed: onWhyPressed,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
