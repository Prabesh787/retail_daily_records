import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_sizes.dart';
import '../extensions/context_ext.dart';
import '../theme/app_text_styles.dart';

/// The one place the app asks a question it will act on.
///
/// A dialog rather than a toast or an undo, because the actions behind it —
/// voiding a bill, cancelling a cheque — are accounting events that propagate
/// through sync to every other device. Undo after the fact is not available, so
/// the question has to come first.
class ConfirmDialog {
  ConfirmDialog._();

  /// Returns true only when the user explicitly confirms; dismissing returns
  /// false, so callers never have to null-check before a destructive action.
  static Future<bool> show({
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) async {
    final palette = Get.context?.palette;

    final result = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        title: Text(title, style: AppTextStyles.h2),
        content: Text(
          message,
          style: AppTextStyles.body.copyWith(color: palette?.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            style: TextButton.styleFrom(foregroundColor: palette?.inkMuted),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(
              // Red only when something is actually being destroyed; a red
              // button on every confirmation teaches people to ignore it.
              foregroundColor: isDestructive ? palette?.moneyOut : null,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}
