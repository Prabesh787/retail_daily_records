import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import '../extensions/context_ext.dart';
import '../theme/app_text_styles.dart';

/// The one primary action on a list screen — New bill, New sale, Add supplier.
///
/// Extended rather than a bare `+`: the icon alone is ambiguous on a screen
/// that lists two kinds of record, and the label costs nothing at the bottom of
/// a list. `AppSizes.listBottomPadding` on that list is what keeps the last row
/// out from under it.
class AppFab extends StatelessWidget {
  const AppFab({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add_rounded,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: palette.brand,
      foregroundColor: Colors.white,
      elevation: 0,
      highlightElevation: 0,
      extendedPadding: const EdgeInsets.symmetric(horizontal: AppSizes.xl),
      shape: const StadiumBorder(),
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: AppTextStyles.button.copyWith(color: Colors.white),
      ),
    );
  }
}
