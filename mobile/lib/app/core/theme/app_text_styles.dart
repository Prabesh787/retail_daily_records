import 'package:flutter/material.dart';

/// The type scale.
///
/// Deliberately **colourless**: every style here leaves `color` null so it
/// inherits from the theme's text colour. A style that hard-codes ink reads
/// wrong the moment it is used on a dark background or inside a coloured badge,
/// and the app has both.
///
/// Two habits carry most of the polish:
///
/// * **Negative letter-spacing on anything large.** Type set at 20px+ with
///   default tracking looks loose; tightening it is most of the difference
///   between "a Flutter app" and a considered one.
/// * **Tabular figures on every number.** Money in a column must line up, and
///   a total must not jitter as its digits change.
class AppTextStyles {
  AppTextStyles._();

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// The big number on a card — today's takings, a supplier's outstanding.
  static const TextStyle display = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
    height: 1.1,
    fontFeatures: _tabular,
  );

  static const TextStyle h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.2,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.25,
  );

  /// A screen title, or the first line of a list row.
  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  /// Small, upper-ish, and used to label a section or a figure. Letter-spacing
  /// goes *positive* here — the one place it should, because tracking is what
  /// makes small caps legible.
  static const TextStyle label = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    height: 1.3,
  );

  static const TextStyle amount = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    fontFeatures: _tabular,
  );

  static const TextStyle amountSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    fontFeatures: _tabular,
  );

  /// For a bill number or a PAN — things that are read character by character.
  static const TextStyle mono = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    fontFeatures: _tabular,
    letterSpacing: 0.2,
  );

  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );
}
