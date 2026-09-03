import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import 'app_palette.dart';
import 'app_text_styles.dart';

/// Both themes are built from one function so light and dark cannot drift
/// apart — a dark mode maintained separately is a dark mode that is always one
/// change behind.
///
/// Everything is driven off [AppPalette]. Screens read colours from the palette
/// rather than from constants, which is what lets the same widget be correct in
/// both.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(AppPalette.light, Brightness.light);
  static ThemeData get dark => _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);

    // Every slot names its own colour.
    //
    // `AppTextStyles` are shapes — size, weight, spacing — and carry no colour
    // on purpose, so the same shape can be inked differently in different
    // places. That makes `copyWith` here dangerous: it *replaces* a slot, so a
    // colourless style silently discards the `bodyColor` applied above it. Text
    // with no colour anywhere in its chain is painted **white** by the engine,
    // which on a white card is not a subtle bug but an invisible one.
    final textTheme = base.textTheme
        .apply(bodyColor: p.ink, displayColor: p.ink)
        .copyWith(
          headlineMedium: AppTextStyles.h1.copyWith(color: p.ink),
          headlineSmall: AppTextStyles.h2.copyWith(color: p.ink),
          titleMedium: AppTextStyles.title.copyWith(color: p.ink),
          bodyLarge: AppTextStyles.body.copyWith(color: p.ink),
          bodyMedium: AppTextStyles.body.copyWith(color: p.ink),
          bodySmall: AppTextStyles.caption.copyWith(color: p.inkMuted),
          labelSmall: AppTextStyles.label.copyWith(color: p.inkSubtle),
        );

    return base.copyWith(
      extensions: [p],
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      textTheme: textTheme,
      colorScheme: base.colorScheme.copyWith(
        primary: p.brand,
        onPrimary: Colors.white,
        secondary: p.info,
        surface: p.surface,
        onSurface: p.ink,
        error: p.moneyOut,
        outline: p.line,
        outlineVariant: p.line,
      ),

      // The header sits on the page background, not on a raised bar, and only
      // grows a hairline once content scrolls under it.
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.h2.copyWith(color: p.ink),
        iconTheme: IconThemeData(color: p.ink, size: 22),
      ),

      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          side: BorderSide(color: p.line),
        ),
      ),

      // Fields sit on the sunken tone rather than on white. On a card, a white
      // input on a white ground reads as a gap rather than as something to
      // type into; the recess is what makes it look tappable.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.sunken,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.lg,
        ),
        hintStyle: AppTextStyles.body.copyWith(color: p.inkSubtle),
        labelStyle: AppTextStyles.caption.copyWith(color: p.inkMuted),
        floatingLabelStyle: AppTextStyles.caption.copyWith(color: p.brand),
        errorStyle: AppTextStyles.caption.copyWith(color: p.moneyOut),
        prefixIconColor: p.inkSubtle,
        suffixIconColor: p.inkSubtle,
        border: _border(p.line),
        enabledBorder: _border(p.line),
        focusedBorder: _border(p.brand, width: 1.6),
        errorBorder: _border(p.moneyOut),
        focusedErrorBorder: _border(p.moneyOut, width: 1.6),
        disabledBorder: _border(p.line),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: p.lineStrong,
          disabledForegroundColor: p.inkSubtle,
          minimumSize: const Size.fromHeight(AppSizes.control),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: p.lineStrong,
          disabledForegroundColor: p.inkSubtle,
          elevation: 0,
          minimumSize: const Size.fromHeight(AppSizes.control),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.ink,
          backgroundColor: p.surface,
          minimumSize: const Size.fromHeight(AppSizes.control),
          side: BorderSide(color: p.lineStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.brand,
          textStyle: AppTextStyles.button,
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.brand,
        foregroundColor: Colors.white,
        elevation: 3,
        highlightElevation: 3,
        extendedTextStyle: AppTextStyles.button.copyWith(color: Colors.white),
        shape: const StadiumBorder(),
      ),

      // Hairline, and no vertical space of its own — rows control their own
      // padding, so a divider that added space would make every list uneven.
      dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),

      chipTheme: base.chipTheme.copyWith(
        backgroundColor: p.surface,
        selectedColor: p.brandSoft,
        checkmarkColor: p.brand,
        side: BorderSide(color: p.line),
        labelStyle: AppTextStyles.caption.copyWith(
          color: p.inkMuted,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: AppTextStyles.caption.copyWith(
          color: p.brand,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
        shape: const StadiumBorder(),
        showCheckmark: false,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.brandSoft,
        elevation: 0,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected) ? p.brand : p.inkSubtle,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppTextStyles.label.copyWith(
            color: states.contains(WidgetState.selected) ? p.brand : p.inkSubtle,
          ),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: p.lineStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSizes.radiusCard),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTextStyles.title.copyWith(color: p.ink),
        contentTextStyle: AppTextStyles.body.copyWith(color: p.inkMuted),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.ink,
        contentTextStyle: AppTextStyles.body.copyWith(color: p.surface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: p.inkSubtle,
        titleTextStyle: AppTextStyles.bodyStrong.copyWith(color: p.ink),
        subtitleTextStyle: AppTextStyles.caption.copyWith(color: p.inkMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.xs,
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.brand,
        linearTrackColor: p.sunken,
        circularTrackColor: p.sunken,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : p.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.brand : p.lineStrong,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      splashFactory: InkSparkle.splashFactory,
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radius),
        borderSide: BorderSide(color: color, width: width),
      );
}
