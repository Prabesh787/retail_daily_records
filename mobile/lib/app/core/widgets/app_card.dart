import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import '../extensions/context_ext.dart';

/// The surface everything in the app sits on.
///
/// Two shapes, and the distinction matters: a **padded** card holds prose or a
/// form, while a **flush** one holds a list whose rows draw their own padding
/// and hairlines edge to edge. Padding a list card leaves the dividers floating
/// short of the edges, which is the single most common way a card list looks
/// slightly wrong without anyone being able to say why.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padded = true,
    this.onTap,
    this.padding,
  });

  /// For a card whose children are full-bleed rows.
  const AppCard.flush({
    super.key,
    required this.child,
    this.onTap,
  })  : padded = false,
        padding = null;

  final Widget child;
  final bool padded;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(AppSizes.radiusCard);

    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: radius,
        border: Border.all(color: palette.line),
        boxShadow: AppSizes.card(palette.shadow),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Padding(
          padding: padded ? (padding ?? AppSizes.cardPadding) : EdgeInsets.zero,
          child: child,
        ),
      ),
    );

    if (onTap == null) return surface;

    // The ripple is clipped to the same radius as the card, so a tap does not
    // splash into the corners.
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, borderRadius: radius, child: surface),
    );
  }
}

/// A heading above a card, optionally with an action on the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.xs, 0, 0, AppSizes.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: context.texts.labelSmall?.copyWith(
                color: palette.inkSubtle,
                letterSpacing: 0.4,
              ),
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: context.texts.labelSmall?.copyWith(
                  color: palette.brand,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The plate an icon sits on — a tinted rounded square.
///
/// Used everywhere a row or tile needs a leading glyph. Having one of these
/// stops each screen inventing its own size and radius.
class IconPlate extends StatelessWidget {
  const IconPlate({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: context.palette.softFor(color),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, size: size * 0.46, color: color),
    );
  }
}

/// Initials on a tinted circle, for a supplier or customer with no photo.
///
/// The tint is chosen from the name, so the same person is always the same
/// colour and a list of them is scannable rather than a column of identical
/// grey discs.
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.name, this.size = 40});

  final String name;
  final double size;

  static const List<int> _hues = [0xFF1E5EFF, 0xFF0E9F5B, 0xFFD98014, 0xFF7C5CFF, 0xFF2E86DE];

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final seed = name.codeUnits.fold<int>(0, (a, b) => a + b);
    final color = Color(_hues[seed % _hues.length]);

    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.palette.softFor(color),
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials,
        style: TextStyle(
          color: color,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
