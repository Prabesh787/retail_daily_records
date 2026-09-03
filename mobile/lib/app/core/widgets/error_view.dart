import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import '../extensions/context_ext.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';

/// What a screen shows when its query failed.
///
/// The fourth state, and the one most often skipped. A failure that arrives as
/// a toast is gone in three seconds and leaves an empty list behind, which
/// reads as "there is nothing here" — the opposite of what happened. This stays
/// on screen, says what went wrong, and offers the retry.
///
/// Everything this app reads comes off the local database, so a failure here is
/// rare and usually real: a corrupt file, a migration that did not run. The
/// message is therefore shown rather than swallowed behind a generic apology.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.title = 'Could not load this',
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

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
                color: palette.moneyOutSoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 27,
                color: palette.moneyOut,
              ),
            ),
            AppSizes.gapLg,
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.title.copyWith(color: palette.ink),
            ),
            AppSizes.gapXs,
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: palette.inkMuted),
              ),
            ),
            if (onRetry != null) ...[
              AppSizes.gapLg,
              AppOutlinedButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                expanded: false,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
