import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import '../extensions/context_ext.dart';
import '../theme/app_text_styles.dart';
import '../theme/tone_colors.dart';

/// One figure on the dashboard: a label, the number, and an optional footnote.
///
/// Smaller type than [AppTextStyles.display] on purpose — these sit two or four
/// to a row, and a headline-sized number in a grid gives four things equal
/// weight, which is the same as giving none of them any.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.foot,
    this.tone = MoneyTone.plain,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? foot;
  final MoneyTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(AppSizes.radiusCard);

    final content = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: radius,
        border: Border.all(color: palette.line),
        boxShadow: AppSizes.card(palette.shadow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: palette.inkSubtle),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label.copyWith(color: palette.inkSubtle),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.amount.copyWith(
              fontSize: 19,
              color: tone.ink(palette),
            ),
          ),
          if (foot != null)
            Text(
              foot!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(
                color: palette.inkSubtle,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, borderRadius: radius, child: content),
    );
  }
}
