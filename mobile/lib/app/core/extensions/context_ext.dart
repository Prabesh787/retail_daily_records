import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

extension ContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;
  Size get screen => MediaQuery.sizeOf(this);
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// The semantic colours, resolved for the current brightness.
  ///
  /// Falls back to the light palette rather than throwing: a widget rendered in
  /// a bare `MaterialApp` — a test, a preview — should still draw.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;

  /// Phones stack the dashboard tiles 2-up; tablets get 4-up.
  bool get isWide => MediaQuery.sizeOf(this).width >= 600;
}
