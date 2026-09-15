import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:youtube_downloader/src/app/design_system/design_system.dart';
import 'package:youtube_downloader/src/app/localization/lang/locale_keys.g.dart';
import 'package:youtube_downloader/src/app/widgets/widgets.dart';

/// Поле ссылки на видео и кнопка «Найти»
class UrlSearchForm extends StatelessWidget {
  static const _fieldHeight = 50.0;

  /// Ширина, с которой поле и кнопка встают в строку
  static const _rowBreakpoint = 640.0;

  final TextEditingController controller;
  final FocusNode? focusNode;

  /// Идёт поиск: кнопка показывает «Ищем…»
  final bool loading;

  /// Искать можно: не ищем и не качаем
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  const UrlSearchForm({
    super.key,
    required this.controller,
    this.focusNode,
    this.loading = false,
    this.enabled = true,
    this.onSubmitted,
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

      if (constraints.maxWidth < _rowBreakpoint) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [input, const SizedBox(height: 12), button],
        );
      }

      /// Во flex-строке CSS элементы тянутся по высоте: кнопка равна полю
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
