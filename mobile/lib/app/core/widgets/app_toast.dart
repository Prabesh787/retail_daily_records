import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/enums/domain_tone.dart';
import '../constants/app_sizes.dart';
import '../extensions/context_ext.dart';
import '../theme/app_text_styles.dart';
import '../theme/tone_colors.dart';

/// Short confirmations: saved, cleared, cancelled, failed.
///
/// A toast, never a dialog. Every message here reports something that has
/// *already happened*, and a dialog for that stops the shopkeeper mid-sale to
/// collect an acknowledgement of news they cannot act on. Anything that needs a
/// decision goes to `ConfirmDialog` instead.
///
/// Callable from a controller, which is where the outcome of a save is known,
/// so it takes no [BuildContext] of its own.
class AppToast {
  AppToast._();

  static const Duration _duration = Duration(milliseconds: 2800);

  static void success(String message, {String? title}) =>
      _show(message, title, DomainTone.success, Icons.check_circle_rounded);

  static void error(String message, {String? title}) =>
      _show(message, title, DomainTone.danger, Icons.error_rounded);

  static void info(String message, {String? title}) =>
      _show(message, title, DomainTone.info, Icons.info_rounded);

  static void warning(String message, {String? title}) =>
      _show(message, title, DomainTone.warning, Icons.warning_rounded);

  static void _show(
    String message,
    String? title,
    DomainTone tone,
    IconData icon,
  ) {
    final context = Get.context;
    if (context == null) return; // No overlay yet — a toast is not worth a crash.

    final palette = context.palette;
    final ink = tone.ink(palette);

    // Only one at a time: a stack of toasts covers the list the user is trying
    // to read, and the newest message is the one that matters.
    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();

    Get.showSnackbar(
      GetSnackBar(
        duration: _duration,
        animationDuration: const Duration(milliseconds: 220),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: palette.surface,
        borderColor: palette.line,
        borderWidth: 1,
        borderRadius: AppSizes.radiusLg,
        boxShadows: AppSizes.lift(palette.shadow),
        margin: const EdgeInsets.all(AppSizes.lg),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        icon: Icon(icon, size: 20, color: ink),
        // Tapping it away beats waiting out the timer when it lands on the row
        // you were about to press.
        onTap: (_) => Get.closeCurrentSnackbar(),
        titleText: title == null
            ? null
            : Text(
                title,
                style: AppTextStyles.bodyStrong.copyWith(color: palette.ink),
              ),
        messageText: Text(
          message,
          style: AppTextStyles.body.copyWith(
            color: title == null ? palette.ink : palette.inkMuted,
          ),
        ),
      ),
    );
  }
}
