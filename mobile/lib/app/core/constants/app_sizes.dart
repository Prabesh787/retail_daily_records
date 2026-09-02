import 'package:flutter/widgets.dart';

/// Spacing, radii and the two shadows the app uses.
///
/// A 4pt scale, so every gap in the app is a multiple of the same unit and
/// nothing lands on an arbitrary 13 or 17. Corners are roomier than Material's
/// defaults — a phone UI made of cards reads better soft than sharp.
class AppSizes {
  AppSizes._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Inputs, buttons and rows all stand this tall, so a form is a stack of
  /// equal blocks rather than a ragged column.
  static const double control = 52;
  static const double rowMin = 60;

  static const double radiusSm = 10;
  static const double radius = 14;
  static const double radiusLg = 18;

  /// Cards. Generous on purpose; this is the shape the whole app is built from.
  static const double radiusCard = 22;
  static const double radiusPill = 999;

  static const EdgeInsets pagePadding = EdgeInsets.all(lg);
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);

  /// Clears a floating action button so the last row is never trapped under it.
  static const EdgeInsets listBottomPadding = EdgeInsets.only(bottom: 104);

  static const SizedBox gapXs = SizedBox(height: xs, width: xs);
  static const SizedBox gapSm = SizedBox(height: sm, width: sm);
  static const SizedBox gapMd = SizedBox(height: md, width: md);
  static const SizedBox gapLg = SizedBox(height: lg, width: lg);
  static const SizedBox gapXl = SizedBox(height: xl, width: xl);

  /// Depth comes from the surface stepping up off the background; the shadow
  /// only softens the edge. Anything heavier looks like a 2014 Material app.
  static List<BoxShadow> card(Color shadow) => [
        BoxShadow(color: shadow, blurRadius: 2, offset: const Offset(0, 1)),
      ];

  /// For something genuinely floating — a sheet, a FAB, a menu.
  static List<BoxShadow> lift(Color shadow) => [
        BoxShadow(
          color: shadow,
          blurRadius: 24,
          spreadRadius: -6,
          offset: const Offset(0, 8),
        ),
      ];
}
