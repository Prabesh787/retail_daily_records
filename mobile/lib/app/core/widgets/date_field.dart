import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import '../extensions/context_ext.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_utils.dart';

/// A date on a form, shown in both calendars.
///
/// Tapping opens the Gregorian picker, because that is the calendar the device
/// knows and the database sorts on. The Bikram Sambat date is shown underneath,
/// derived — the shop reads BS, so a field that only says "26 Aug 2026" makes
/// the shopkeeper convert in their head to check it against the bill in their
/// hand.
///
/// Where the paperwork's own BS date matters it is captured separately as text;
/// this field is the AD date and its faithful conversion, nothing more.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.enabled = true,
  });

  final String label;

  /// Epoch millis.
  final int value;

  final ValueChanged<int> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool enabled;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: AppDateUtils.fromMs(value),
      // The shop's records do not predate the app by years, and a picker that
      // scrolls back to 1900 buries the dates anyone actually enters.
      firstDate: firstDate ?? DateTime(now.year - 5),
      lastDate: lastDate ?? DateTime(now.year + 1, 12, 31),
    );

    if (picked != null) onChanged(picked.millisecondsSinceEpoch);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: palette.inkMuted),
        ),
        AppSizes.gapXs,
        Material(
          color: palette.sunken,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? () => _pick(context) : null,
            child: Container(
              height: AppSizes.control,
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
              decoration: BoxDecoration(
                border: Border.all(color: palette.line),
                borderRadius: BorderRadius.circular(AppSizes.radius),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_rounded,
                    size: 19,
                    color: palette.inkSubtle,
                  ),
                  AppSizes.gapMd,
                  Expanded(
                    child: Text(
                      AppDateUtils.datePair(value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        color: enabled ? palette.ink : palette.inkSubtle,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: palette.inkSubtle,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
