import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

/// Page title with an optional description and actions on the right
class AppPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: context.text.header4Semibold),
            ),
            if (subtitle case final subtitle?) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: context.text.captionRegular.copyWith(
                  color: context.color.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
      if (trailing case final trailing?) ...[
        const SizedBox(width: 16),
        trailing,
      ],
    ],
  );
}
