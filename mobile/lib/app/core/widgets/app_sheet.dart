import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import '../extensions/context_ext.dart';
import '../theme/app_text_styles.dart';
import 'app_card.dart';
import 'app_list_row.dart';

/// The bottom sheet used for every picker and short confirmation.
///
/// A sheet rather than a pushed screen because these choices are made *about*
/// something on the page behind — which supplier, which date range — and keeping
/// that context visible is the whole reason the pattern exists. A full screen
/// for a five-item list also costs two transitions to answer one question.
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.title,
    required this.child,
    this.footer,
  });

  final String title;
  final Widget child;

  /// Pinned below the scroll area — a Save or Apply that must stay reachable
  /// however long the content is.
  final Widget? footer;

  /// Opens [child] in a sheet and completes with whatever the sheet pops.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    Widget? footer,
    bool dismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      useSafeArea: true,
      // The sheet paints its own rounded surface; letting the theme paint one
      // too leaves a square corner peeking out behind the rounded one.
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (context) => AppSheet(title: title, child: child),
    );
  }

  /// A one-tap picker. Completes with the chosen value, or null if dismissed.
  static Future<T?> options<T>({
    required BuildContext context,
    required String title,
    required List<SheetOption<T>> options,
    T? selected,
  }) {
    return show<T>(
      context: context,
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            _OptionRow<T>(option: option, isSelected: option.value == selected),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      constraints: BoxConstraints(maxHeight: context.screen.height * 0.86),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: AppSizes.lift(palette.shadow),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            width: 36,
            margin: const EdgeInsets.only(top: AppSizes.sm, bottom: AppSizes.xs),
            decoration: BoxDecoration(
              color: palette.lineStrong,
              borderRadius: BorderRadius.circular(AppSizes.radiusPill),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.sm,
              AppSizes.sm,
              AppSizes.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.title.copyWith(
                      fontSize: 17,
                      color: palette.ink,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: palette.inkMuted,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              // Clears the gesture bar; the sheet is already inside a safe
              // area, so this is breathing room rather than a second inset.
              padding: const EdgeInsets.only(bottom: AppSizes.lg),
              child: child,
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.lg,
                AppSizes.sm,
                AppSizes.lg,
                AppSizes.lg,
              ),
              child: footer,
            ),
        ],
      ),
    );
  }
}

/// One row in [AppSheet.options].
class SheetOption<T> {
  const SheetOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.tint,
  });

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;

  /// Colours the icon plate — a payment mode's tone, say.
  final Color? tint;
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({required this.option, required this.isSelected});

  final SheetOption<T> option;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppListRow(
      title: option.label,
      subtitle: option.subtitle,
      leading: option.icon == null
          ? null
          : IconPlate(
              icon: option.icon!,
              color: option.tint ?? palette.brand,
            ),
      trailing: [
        if (isSelected)
          Icon(Icons.check_rounded, size: 20, color: palette.brand),
      ],
      onTap: () => Navigator.of(context).pop<T>(option.value),
    );
  }
}

