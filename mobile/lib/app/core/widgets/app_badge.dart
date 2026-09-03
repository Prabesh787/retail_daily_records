import 'package:flutter/material.dart';

import '../../data/enums/domain_tone.dart';
import '../constants/app_sizes.dart';
import '../extensions/context_ext.dart';
import '../theme/app_text_styles.dart';
import '../theme/tone_colors.dart';

/// A status pill: cleared, issued, credit, itemised.
///
/// Named `AppBadge` because Material ships its own `Badge` — a notification
/// dot, an entirely different thing — and one unqualified import would silently
/// give a screen the wrong one.
///
/// The dot is on by default and off for anything that is a *label* rather than
/// a *state*: a payment mode is a fact about the row, while "Issued" is a
/// condition that will change, and the dot is what distinguishes them at a
/// glance without reading the word.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.tone = DomainTone.neutral,
    this.dot = true,
    this.icon,
  });

  final String label;
  final DomainTone tone;
  final bool dot;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ink = tone.ink(palette);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: tone.ground(palette),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              height: 5,
              width: 5,
              decoration: BoxDecoration(color: ink, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ] else if (icon != null) ...[
            Icon(icon, size: 12, color: ink),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.label.copyWith(color: ink),
          ),
        ],
      ),
    );
  }
}
