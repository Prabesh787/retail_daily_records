import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import '../extensions/context_ext.dart';
import '../theme/app_text_styles.dart';
import '../theme/tone_colors.dart';

/// The row every list in this app is built from: a leading slot, two lines of
/// text, a right-hand stack of one or two figures, and an optional chevron.
///
/// It paints its own surface rather than sitting transparent on whatever is
/// behind it. That is not decoration — an [InkWell] splashes onto the nearest
/// [Material] ancestor, so a transparent row inside `AppCard.flush` would ripple
/// *underneath* the card's own background and the tap would look dead.
///
/// Deliberately not `ListTile`: the trailing slot here is a column of figures
/// with money-aware colour, the vertical rhythm is the app's rather than
/// Material's, and `ListTile`'s content padding fights the flush card.
class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing = const [],
    this.chevron = false,
    this.onTap,
    this.onLongPress,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;

  /// Stacked right-aligned, usually a [RowAmount] over a badge or caption.
  final List<Widget> trailing;

  final bool chevron;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: palette.surface,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.rowMin),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.lg,
              vertical: AppSizes.md,
            ),
            child: Row(
              children: [
                if (leading != null) ...[leading!, AppSizes.gapMd],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyStrong.copyWith(
                          color: palette.ink,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: palette.inkMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing.isNotEmpty) ...[
                  AppSizes.gapMd,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < trailing.length; i++) ...[
                        if (i > 0) const SizedBox(height: 3),
                        trailing[i],
                      ],
                    ],
                  ),
                ],
                if (chevron)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSizes.xs),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: palette.inkSubtle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A figure in a row's trailing slot, coloured by which way the money went.
class RowAmount extends StatelessWidget {
  const RowAmount(this.value, {super.key, this.tone = MoneyTone.plain});

  final String value;
  final MoneyTone tone;

  @override
  Widget build(BuildContext context) => Text(
        value,
        maxLines: 1,
        style: AppTextStyles.amountSmall.copyWith(
          color: tone.ink(context.palette),
        ),
      );
}

/// The quiet second line under a [RowAmount] — a count, a mode, a date.
class RowCaption extends StatelessWidget {
  const RowCaption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        maxLines: 1,
        style: AppTextStyles.label.copyWith(
          color: context.palette.inkSubtle,
          fontWeight: FontWeight.w500,
        ),
      );
}

/// The hairline between rows.
///
/// Inset to clear the leading avatar by default, the way native lists do —
/// a full-width rule between rows that both start with an avatar cuts through
/// the column of circles and makes the list look like a table.
class RowDivider extends StatelessWidget {
  const RowDivider({super.key, this.full = false});

  final bool full;

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: EdgeInsets.only(left: full ? 0 : AppSizes.lg),
        color: context.palette.line,
      );
}
