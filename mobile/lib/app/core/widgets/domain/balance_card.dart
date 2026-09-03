import 'package:flutter/material.dart';

import '../../constants/app_sizes.dart';
import '../../domain/money.dart';
import '../../extensions/context_ext.dart';
import '../../theme/app_text_styles.dart';

/// The headline figure on the supplier screens: what the shop still owes.
///
/// The split underneath is the whole point. Money already debited and a cheque
/// handed over but not yet presented are both "paid" as far as the supplier is
/// concerned, and they are emphatically not the same thing as far as the bank
/// balance is concerned. Reporting one number would hide the difference exactly
/// where it matters most.
///
/// Solid brand colour rather than a card, because there is one of these per
/// screen and its job is to be the thing you read first.
class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.amount,
    this.label = 'You owe',
    this.caption,
    this.cleared,
    this.uncleared,
  });

  final Money amount;
  final String label;
  final String? caption;

  /// Given together or not at all; omitting them drops the split entirely.
  final Money? cleared;
  final Money? uncleared;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final showSplit = cleared != null && uncleared != null;

    return Container(
      padding: const EdgeInsets.all(AppSizes.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppSizes.lift(palette.shadow),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.brand, palette.brandStrong],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // A flat rectangle of one colour at this size looks like a missing
          // image; the highlight gives it a light source.
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              height: 180,
              width: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTextStyles.label.copyWith(
                  letterSpacing: 0.6,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                amount.display(),
                style: AppTextStyles.display.copyWith(color: Colors.white),
              ),
              if (caption != null)
                Text(
                  caption!,
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              if (showSplit) ...[
                AppSizes.gapLg,
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                AppSizes.gapLg,
                Row(
                  children: [
                    Flexible(
                      child: _Split(label: 'Paid & cleared', amount: cleared!),
                    ),
                    AppSizes.gapXl,
                    Flexible(
                      child: _Split(
                        label: 'Cheques not cleared',
                        amount: uncleared!,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Split extends StatelessWidget {
  const _Split({required this.label, required this.amount});

  final String label;
  final Money amount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          amount.display(decimals: false),
          maxLines: 1,
          style: AppTextStyles.amountSmall.copyWith(
            fontSize: 15,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
