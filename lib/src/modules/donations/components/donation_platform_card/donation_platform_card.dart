import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:black_cat/src/app/design_system/design_system.dart';
import 'package:black_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/widgets/widgets.dart';

/// A way to support the developer: the service, a QR code of the link for
/// a phone, and buttons to open or copy the link
class DonationPlatformCard extends StatefulWidget {
  static const qrSize = 152.0;
  static const _logoSize = 44.0;
  static const _copiedDuration = Duration(seconds: 2);

  final DonationPlatformModel platform;
  final String description;
  final VoidCallback? onOpenPressed;

  /// The card confirms the copy by itself
  final VoidCallback? onCopyPressed;

  const DonationPlatformCard({
    super.key,
    required this.platform,
    required this.description,
    this.onOpenPressed,
    this.onCopyPressed,
  });

  @override
  State<DonationPlatformCard> createState() => _DonationPlatformCardState();
}

class _DonationPlatformCardState extends State<DonationPlatformCard> {
  var _hovered = false;
  Timer? _copiedTimer;

  bool get _copied => _copiedTimer?.isActive ?? false;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  void _copy() {
    widget.onCopyPressed?.call();

    _copiedTimer?.cancel();
    setState(() {
      _copiedTimer = Timer(DonationPlatformCard._copiedDuration, () {
        if (mounted) setState(() {});
      });
    });
  }

  Widget _logo(BuildContext context) => Container(
    width: DonationPlatformCard._logoSize,
    height: DonationPlatformCard._logoSize,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: context.color.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.color.border),
    ),
    child: Image.asset(widget.platform.logoAsset, fit: BoxFit.contain),
  );

  Widget _qrCode(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.color.qrBackground,
      borderRadius: BorderRadius.circular(16),
    ),
    child: SizedBox.square(
      dimension: DonationPlatformCard.qrSize,
      child: PrettyQrView(
        qrImage: QrImage(
          QrCode.fromData(
            data: widget.platform.url,

            /// The logo in the middle covers some modules
            errorCorrectLevel: QrErrorCorrectLevel.H,
          ),
        ),
        decoration: PrettyQrDecoration(
          shape: PrettyQrSmoothSymbol(color: context.color.qrForeground),
          background: context.color.transparent,
          quietZone: PrettyQrQuietZone.zero,
          image: PrettyQrDecorationImage(
            image: AssetImage(widget.platform.logoAsset),
            scale: 0.22,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.color.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _hovered
              ? context.color.accent.withValues(alpha: 0.6)
              : context.color.border,
        ),
        boxShadow: [
          if (_hovered)
            BoxShadow(
              color: context.color.accent.withValues(alpha: 0.12),
              blurRadius: 20,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _logo(context),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.platform.title,
                      style: context.text.bodyMedium.copyWith(
                        color: context.color.textPrimary,
                      ),
                    ),
                    Text(
                      widget.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.captionRegular.copyWith(
                        color: context.color.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(child: _qrCode(context)),
          const SizedBox(height: 8),
          Text(
            LocaleKeys.app_donations_qr_hint.tr(),
            textAlign: TextAlign.center,
            style: context.text.footnoteRegular.copyWith(
              color: context.color.textHint,
            ),
          ),

          /// Cards of one row have the same height: the buttons stay
          /// at the bottom
          const Spacer(),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: AppPrimaryButton(
                  title: LocaleKeys.app_donations_open.tr(),
                  onPressed: widget.onOpenPressed,
                ),
              ),
              const SizedBox(width: 8),
              AppIconButton(
                icon: _copied
                    ? Icons.check_rounded
                    : Icons.content_copy_rounded,
                tooltip: _copied
                    ? LocaleKeys.app_donations_link_copied.tr()
                    : LocaleKeys.app_donations_copy_link.tr(),
                iconColor: _copied ? context.color.accent : null,
                size: 44,
                iconSize: 20,
                onPressed: widget.onCopyPressed == null ? null : _copy,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _copied
                ? LocaleKeys.app_donations_link_copied.tr()
                : widget.platform.displayUrl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.text.footnoteRegular.copyWith(
              color: _copied
                  ? context.color.accent
                  : context.color.textTertiary,
            ),
          ),
        ],
      ),
    ),
  );
}
