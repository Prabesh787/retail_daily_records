import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import '../extensions/context_ext.dart';

/// The primary action on a form or a sheet.
///
/// Shape, height and type come from the theme rather than from here — this adds
/// only the three things a themed [ElevatedButton] cannot express on its own:
/// a leading icon, a loading state that keeps the button's size, and the
/// destructive variant.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.color,
    this.expanded = true,
  }) : _destructive = false;

  /// Voiding a bill, cancelling a cheque, deleting a party.
  const AppButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = true,
  }) : color = null,
       _destructive = true;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  /// Overrides the brand colour. Rarely wanted; prefer [AppButton.danger].
  final Color? color;

  final bool expanded;

  final bool _destructive;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final background = _destructive ? palette.moneyOut : color;

    final button = ElevatedButton(
      // Disabled while saving, so a double tap cannot post the same bill twice.
      onPressed: isLoading ? null : onPressed,
      style: background == null
          ? null
          : ElevatedButton.styleFrom(backgroundColor: background),
      child: isLoading
          // Sized to match the label's line box, so the button does not resize
          // the moment it is pressed.
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 18), AppSizes.gapSm],
                Text(label),
              ],
            ),
    );

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// The secondary action beside an [AppButton] — Cancel, or a second path that
/// is not the one being recommended.
class AppOutlinedButton extends StatelessWidget {
  const AppOutlinedButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), AppSizes.gapSm],
          Text(label),
        ],
      ),
    );

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
