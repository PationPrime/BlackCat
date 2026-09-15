part of 'localization.dart';

/// Applies a language change to the whole app.
///
/// `.tr()` texts do not subscribe to the locale, so after a language switch
/// widgets would keep the old language until their next rebuild. The subtree
/// is rebuilt without recreating it: the navigation stack and screen state stay.
/// Dates and numbers of `intl` follow the same language
class AppLocaleRebuilder extends StatefulWidget {
  final Widget child;

  /// Called after the first frame with loaded translations and after every
  /// language change: texts outside the widget tree, such as the tray menu,
  /// can be built from this moment
  final ValueChanged<Locale>? onLocaleApplied;

  const AppLocaleRebuilder({
    super.key,
    required this.child,
    this.onLocaleApplied,
  });

  @override
  State<AppLocaleRebuilder> createState() => _AppLocaleRebuilderState();
}

class _AppLocaleRebuilderState extends State<AppLocaleRebuilder> {
  Locale? _locale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final locale = context.locale;

    if (locale == _locale) return;

    Intl.defaultLocale = locale.toLanguageTag();

    final isLanguageChange = _locale != null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (isLanguageChange) {
        _markSubtreeNeedsBuild(context as Element);
      }

      widget.onLocaleApplied?.call(locale);
    });

    _locale = locale;
  }

  static void _markSubtreeNeedsBuild(Element element) =>
      element.visitChildren((child) {
        child.markNeedsBuild();
        _markSubtreeNeedsBuild(child);
      });

  @override
  Widget build(BuildContext context) => widget.child;
}
