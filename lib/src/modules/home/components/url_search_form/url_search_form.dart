import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:black_cat/src/app/design_system/design_system.dart';
import 'package:black_cat/src/app/localization/lang/locale_keys.g.dart';
import 'package:black_cat/src/app/widgets/widgets.dart';

/// Video link field and the Search button. Enter in the field searches too
class UrlSearchForm extends StatelessWidget {
  static const _fieldHeight = 50.0;

  final TextEditingController controller;
  final FocusNode? focusNode;

  /// Search is in progress: the button shows "Searching…"
  final bool loading;

  /// Searching is allowed: no search is running
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  /// Width from which the field and the button go into one row
  final double rowBreakpoint;

  const UrlSearchForm({
    super.key,
    required this.controller,
    this.focusNode,
    this.loading = false,
    this.enabled = true,
    this.onSubmitted,
    this.rowBreakpoint = 640,
  });

  void _submit() {
    if (!enabled) return;

    onSubmitted?.call(controller.text);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      /// A desktop keyboard Enter is handled here, before the text input:
      /// the search starts once, from either Enter key
      final input = CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): _submit,
          const SingleActivator(LogicalKeyboardKey.numpadEnter): _submit,
        },
        child: AppTextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: true,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.search,
          height: _fieldHeight,
          hintText: LocaleKeys.app_downloader_url_hint.tr(),

          /// The search key of an on-screen keyboard
          onSubmitted: (_) => _submit(),
        ),
      );

      final button = AppPrimaryButton(
        title: loading
            ? LocaleKeys.app_downloader_buttons_searching.tr()
            : LocaleKeys.app_downloader_buttons_search.tr(),
        onPressed: enabled ? _submit : null,
        buttonColor: context.color.buttonNeutral,
        hoverColor: context.color.buttonNeutralHover,
        titleColor: context.color.onButtonNeutral,
      );

      if (constraints.maxWidth < rowBreakpoint) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [input, const SizedBox(height: 12), button],
        );
      }

      /// In a CSS flex row items stretch vertically: the button matches the field
      return SizedBox(
        height: _fieldHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: input),
            const SizedBox(width: 12),
            button,
          ],
        ),
      );
    },
  );
}
