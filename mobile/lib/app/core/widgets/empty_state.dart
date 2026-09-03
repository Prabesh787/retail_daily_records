import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import '../extensions/context_ext.dart';
import '../theme/app_text_styles.dart';

/// What a list shows when it has nothing in it.
///
/// A title, a sentence and — where there is one — the action that would fill
/// the screen. An empty list with no explanation is indistinguishable from a
/// failed load, and offering the action here is what turns a dead end into the
/// obvious next tap.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.xl,
          vertical: AppSizes.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 60,
              width: 60,
              decoration: BoxDecoration(
                color: palette.sunken,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 26, color: palette.inkSubtle),
            ),
            AppSizes.gapLg,
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.title.copyWith(color: palette.ink),
            ),
            if (message != null) ...[
              AppSizes.gapXs,
              // Held narrow: a full-width line of centred prose is hard to
              // track back to the start of.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(color: palette.inkMuted),
                ),
              ),
            ],
            if (actionLabel != null) ...[
              AppSizes.gapMd,
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
