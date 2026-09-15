import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:youtube_downloader/src/app/design_system/design_system.dart';
import 'package:youtube_downloader/src/app/localization/lang/locale_keys.g.dart';
import 'package:youtube_downloader/src/app/widgets/widgets.dart';

/// Video link field and the Search button
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

  void _submit() => onSubmitted?.call(controller.text);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final input = AppTextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        keyboardType: TextInputType.url,
        height: _fieldHeight,
        hintText: LocaleKeys.app_downloader_url_hint.tr(),
        onSubmitted: enabled ? (_) => _submit() : null,
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
          children: [Expanded(child: input), const SizedBox(width: 12), button],
        ),
      );
    },
  );
}
