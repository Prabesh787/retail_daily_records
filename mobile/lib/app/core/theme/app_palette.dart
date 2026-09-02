import 'package:flutter/material.dart';

/// Every colour the app uses, named for what it *means* rather than what it is.
///
/// A `ThemeExtension` rather than a wall of static constants, because the app
/// has a real dark mode: `AppColors.textSecondary` can only ever be one colour,
/// and a screen built from constants either looks wrong at night or grows a
/// `context.isDark ? … : …` at every call site. Reading the palette off the
/// theme means a widget states its intent once and gets the right value in both.
///
/// Money has a direction, and the palette says so: [moneyIn] for takings,
/// [moneyOut] for what the shop spends or owes, [pending] for a cheque that has
/// been handed over but not yet debited. Those three carry most of the meaning
/// in this app, so they are tokens rather than judgement calls in each widget.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brand,
    required this.brandSoft,
    required this.brandStrong,
    required this.moneyIn,
    required this.moneyInSoft,
    required this.moneyOut,
    required this.moneyOutSoft,
    required this.pending,
    required this.pendingSoft,
    required this.info,
    required this.infoSoft,
    required this.neutralSoft,
    required this.bg,
    required this.surface,
    required this.sunken,
    required this.ink,
    required this.inkMuted,
    required this.inkSubtle,
    required this.line,
    required this.lineStrong,
    required this.shadow,
  });

  /// The shop's blue. Unchanged from the app's original identity — this is a
  /// refinement of the existing look, not a rebrand.
  final Color brand;

  /// A tinted ground for the brand colour: selected chips, icon plates.
  final Color brandSoft;
  final Color brandStrong;

  final Color moneyIn;
  final Color moneyInSoft;
  final Color moneyOut;
  final Color moneyOutSoft;

  /// Handed over, not yet cleared.
  final Color pending;
  final Color pendingSoft;

  final Color info;
  final Color infoSoft;

  /// The ground for a badge that means nothing in particular.
  final Color neutralSoft;

  /// Page background, card background, and the recess a card sits in.
  final Color bg;
  final Color surface;
  final Color sunken;

  /// Text, in three weights of emphasis.
  final Color ink;
  final Color inkMuted;
  final Color inkSubtle;

  final Color line;
  final Color lineStrong;

  /// Card shadows are barely visible by design — depth comes from the surface
  /// stepping up from the background, not from a drop shadow.
  final Color shadow;

  // ---- Light ---------------------------------------------------------------

  static const AppPalette light = AppPalette(
    brand: Color(0xFF1E5EFF),
    brandSoft: Color(0xFFEAF0FF),
    brandStrong: Color(0xFF1442B8),
    moneyIn: Color(0xFF0E9F5B),
    moneyInSoft: Color(0xFFE3F7ED),
    moneyOut: Color(0xFFE23D3D),
    moneyOutSoft: Color(0xFFFDEAEA),
    pending: Color(0xFFD98014),
    pendingSoft: Color(0xFFFDF1DF),
    info: Color(0xFF2E86DE),
    infoSoft: Color(0xFFE7F1FD),
    neutralSoft: Color(0xFFEEF1F6),
    bg: Color(0xFFF5F6FA),
    surface: Color(0xFFFFFFFF),
    sunken: Color(0xFFECEEF4),
    ink: Color(0xFF141828),
    inkMuted: Color(0xFF5C6479),
    inkSubtle: Color(0xFF8A92A6),
    line: Color(0xFFE4E7EF),
    lineStrong: Color(0xFFCFD5E2),
    shadow: Color(0x14141828),
  );

  // ---- Dark ----------------------------------------------------------------
  //
  // Not the light palette inverted. Saturated colours vibrate against a dark
  // ground, so the accents are lifted in lightness and dropped in saturation,
  // and the "soft" grounds become deep tints rather than pale washes.

  static const AppPalette dark = AppPalette(
    brand: Color(0xFF6D93FF),
    brandSoft: Color(0xFF17223F),
    brandStrong: Color(0xFF97B4FF),
    moneyIn: Color(0xFF3DD68C),
    moneyInSoft: Color(0xFF0B2E20),
    moneyOut: Color(0xFFFF7A7A),
    moneyOutSoft: Color(0xFF3A1418),
    pending: Color(0xFFF5B547),
    pendingSoft: Color(0xFF362408),
    info: Color(0xFF63B3F5),
    infoSoft: Color(0xFF0B2437),
    neutralSoft: Color(0xFF1D2334),
    bg: Color(0xFF0C0F19),
    surface: Color(0xFF161B29),
    sunken: Color(0xFF11151F),
    ink: Color(0xFFEDF0F7),
    inkMuted: Color(0xFFA3ABC0),
    inkSubtle: Color(0xFF6E778D),
    line: Color(0xFF242B3E),
    lineStrong: Color(0xFF343D55),
    shadow: Color(0x33000000),
  );

  /// The tinted ground that belongs with a foreground colour, for badges and
  /// icon plates. Falls back to a translucent tint for anything not in the set.
  Color softFor(Color foreground) {
    if (foreground == moneyIn) return moneyInSoft;
    if (foreground == moneyOut) return moneyOutSoft;
    if (foreground == pending) return pendingSoft;
    if (foreground == info) return infoSoft;
    if (foreground == brand) return brandSoft;
    return foreground.withValues(alpha: 0.12);
  }

  @override
  AppPalette copyWith({
    Color? brand,
    Color? brandSoft,
    Color? brandStrong,
    Color? moneyIn,
    Color? moneyInSoft,
    Color? moneyOut,
    Color? moneyOutSoft,
    Color? pending,
    Color? pendingSoft,
    Color? info,
    Color? infoSoft,
    Color? neutralSoft,
    Color? bg,
    Color? surface,
    Color? sunken,
    Color? ink,
    Color? inkMuted,
    Color? inkSubtle,
    Color? line,
    Color? lineStrong,
    Color? shadow,
  }) =>
      AppPalette(
        brand: brand ?? this.brand,
        brandSoft: brandSoft ?? this.brandSoft,
        brandStrong: brandStrong ?? this.brandStrong,
        moneyIn: moneyIn ?? this.moneyIn,
        moneyInSoft: moneyInSoft ?? this.moneyInSoft,
        moneyOut: moneyOut ?? this.moneyOut,
        moneyOutSoft: moneyOutSoft ?? this.moneyOutSoft,
        pending: pending ?? this.pending,
        pendingSoft: pendingSoft ?? this.pendingSoft,
        info: info ?? this.info,
        infoSoft: infoSoft ?? this.infoSoft,
        neutralSoft: neutralSoft ?? this.neutralSoft,
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        sunken: sunken ?? this.sunken,
        ink: ink ?? this.ink,
        inkMuted: inkMuted ?? this.inkMuted,
        inkSubtle: inkSubtle ?? this.inkSubtle,
        line: line ?? this.line,
        lineStrong: lineStrong ?? this.lineStrong,
        shadow: shadow ?? this.shadow,
      );

  /// Lets the whole palette cross-fade when the theme switches, rather than
  /// snapping one frame after the rest of the UI.
  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      brand: mix(brand, other.brand),
      brandSoft: mix(brandSoft, other.brandSoft),
      brandStrong: mix(brandStrong, other.brandStrong),
      moneyIn: mix(moneyIn, other.moneyIn),
      moneyInSoft: mix(moneyInSoft, other.moneyInSoft),
      moneyOut: mix(moneyOut, other.moneyOut),
      moneyOutSoft: mix(moneyOutSoft, other.moneyOutSoft),
      pending: mix(pending, other.pending),
      pendingSoft: mix(pendingSoft, other.pendingSoft),
      info: mix(info, other.info),
      infoSoft: mix(infoSoft, other.infoSoft),
      neutralSoft: mix(neutralSoft, other.neutralSoft),
      bg: mix(bg, other.bg),
      surface: mix(surface, other.surface),
      sunken: mix(sunken, other.sunken),
      ink: mix(ink, other.ink),
      inkMuted: mix(inkMuted, other.inkMuted),
      inkSubtle: mix(inkSubtle, other.inkSubtle),
      line: mix(line, other.line),
      lineStrong: mix(lineStrong, other.lineStrong),
      shadow: mix(shadow, other.shadow),
    );
  }
}
