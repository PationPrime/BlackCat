import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

/// Single-line input field: rounded corners, accent border when focused
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final bool autofocus;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final double height;

  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.autofocus = false,
    this.keyboardType,
    this.onSubmitted,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    final lineHeight = context.text.bodyRegular.fontSize! *
        context.text.bodyRegular.height!;

    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color),
    );

    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      cursorColor: context.color.textPrimary,
      style: context.text.bodyRegular,
      strutStyle: StrutStyle.fromTextStyle(
        context.text.bodyRegular,
        forceStrutHeight: true,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: hintText,
        hintStyle: context.text.bodyRegular.copyWith(
          color: context.color.textHint,
        ),
        filled: true,
        fillColor: context.color.surface,
        hoverColor: context.color.surface,
        constraints: BoxConstraints.tightFor(height: height),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: (height - lineHeight) / 2,
        ),
        enabledBorder: border(context.color.border),
        focusedBorder: border(context.color.accent),
      ),
    );
  }
}
