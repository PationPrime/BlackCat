part of 'video_player_dialog.dart';

/// Current playback speed; a click opens the speed menu
class _VideoSpeedButton extends StatelessWidget {
  final double rate;
  final ValueChanged<double> onRateChanged;
  final ValueChanged<bool> onMenuChanged;

  const _VideoSpeedButton({
    required this.rate,
    required this.onRateChanged,
    required this.onMenuChanged,
  });

  /// `1`, `1.25`, `1.5`, `2`
  static String _format(double rate) =>
      rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : '$rate';

  Future<void> _openMenu(BuildContext context) async {
    final button = context.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final bounds = Rect.fromPoints(
      button.localToGlobal(Offset.zero, ancestor: overlay),
      button.localToGlobal(
        button.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    );

    onMenuChanged(true);

    final selected = await showMenu<double>(
      context: context,
      position: RelativeRect.fromRect(bounds, Offset.zero & overlay.size),
      initialValue: rate,
      color: context.color.playerMenu,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem<double>(
          enabled: false,
          height: 36,
          child: Text(
            LocaleKeys.app_player_controls_speed.tr(),
            style: context.text.captionMedium.copyWith(
              color: context.color.onPlayerSecondary,
            ),
          ),
        ),
        for (final option in PlayerConstants.playbackRates)
          PopupMenuItem<double>(
            value: option,
            height: 40,
            child: Row(
              children: [
                SizedBox(
                  width: 15,
                  child: option == rate
                      ? Assets.icons.iconCheck.svg(
                          height: 15,
                          width: 15,
                          color: context.color.onPlayer,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  option == 1
                      ? LocaleKeys.app_player_controls_speed_normal.tr()
                      : _format(option),
                  style: context.text.captionMedium.copyWith(
                    color: context.color.onPlayer,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    onMenuChanged(false);

    if (selected != null) onRateChanged(selected);
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    message: LocaleKeys.app_player_controls_speed.tr(),
    waitDuration: const Duration(milliseconds: 400),
    child: AppPressable(
      onPressed: () => _openMenu(context),
      builder: (context, highlighted) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 44,
        constraints: const BoxConstraints(minWidth: 52),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: highlighted
              ? context.color.playerHover
              : context.color.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${_format(rate)}×',
          style: context.text.bodyMedium.copyWith(
            color: context.color.onPlayer,
            fontSize: 12,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    ),
  );
}
