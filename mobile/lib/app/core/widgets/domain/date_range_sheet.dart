import 'package:flutter/material.dart';

import '../../../data/models/fiscal_year.dart';
import '../../constants/app_sizes.dart';
import '../../extensions/context_ext.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/date_utils.dart';
import '../app_list_row.dart';
import '../app_sheet.dart';

/// The window a list or report covers.
///
/// Both bounds are optional and inclusive, held as epoch millis to match the
/// date columns: [from] at the start of its day, [to] at the end of its day, so
/// a range of "today to today" contains today's records rather than only those
/// stamped exactly midnight.
@immutable
class DateRange {
  const DateRange({this.from, this.to});

  /// Everything, the default on a screen the shopkeeper has not filtered.
  const DateRange.all() : from = null, to = null;

  /// Whole days, normalised to the bounds of each — the form every caller
  /// actually wants, and the one that is easy to get subtly wrong.
  factory DateRange.days(DateTime from, DateTime to) => DateRange(
    from: AppDateUtils.startOfDay(from).millisecondsSinceEpoch,
    to: AppDateUtils.endOfDay(to).millisecondsSinceEpoch,
  );

  final int? from;
  final int? to;

  bool get isAll => from == null && to == null;

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// A named window offered in the sheet.
class DateRangePreset {
  const DateRangePreset({required this.label, required this.range});

  final String label;
  final DateRange range;
}

/// The offered windows, presets first.
///
/// Presets lead because a specific day is the rare case: the questions a shop
/// asks of its own books are "today", "this month" and "this year", and making
/// those one tap each is worth more than a calendar.
///
/// The fiscal year is included when there is one, because every figure that
/// gets reported to anyone else is bounded by it.
List<DateRangePreset> buildDateRangePresets({FiscalYear? fiscalYear}) {
  final now = DateTime.now();

  return [
    const DateRangePreset(label: 'All time', range: DateRange.all()),
    DateRangePreset(label: 'Today', range: DateRange.days(now, now)),
    DateRangePreset(
      label: 'Last 7 days',
      range: DateRange.days(now.subtract(const Duration(days: 6)), now),
    ),
    DateRangePreset(
      label: 'This month',
      range: DateRange(
        from: AppDateUtils.startOfMonthMs(now),
        to: AppDateUtils.endOfTodayMs(),
      ),
    ),
    DateRangePreset(
      label: 'Last 30 days',
      range: DateRange.days(now.subtract(const Duration(days: 29)), now),
    ),
    if (fiscalYear != null)
      DateRangePreset(
        label: 'FY ${fiscalYear.name}',
        range: DateRange(from: fiscalYear.startDate, to: fiscalYear.endDate),
      ),
  ];
}

/// The label for the current range — a preset's name where it matches one,
/// and the dates themselves where it does not.
String describeRange(DateRange range, List<DateRangePreset> presets) {
  for (final preset in presets) {
    if (preset.range == range) return preset.label;
  }

  final from = range.from;
  final to = range.to;
  if (from != null && to != null) {
    return '${AppDateUtils.formatDateShort(from)} – '
        '${AppDateUtils.formatDate(to)}';
  }
  if (from != null) return 'From ${AppDateUtils.formatDate(from)}';
  if (to != null) return 'Until ${AppDateUtils.formatDate(to)}';
  return 'All time';
}

/// Opens the range picker. Completes with the chosen range, or null if the
/// sheet was dismissed without a choice.
Future<DateRange?> showDateRangeSheet({
  required BuildContext context,
  required DateRange selected,
  FiscalYear? fiscalYear,
}) {
  final presets = buildDateRangePresets(fiscalYear: fiscalYear);

  return AppSheet.show<DateRange>(
    context: context,
    title: 'Date range',
    child: _DateRangeBody(presets: presets, selected: selected),
  );
}

class _DateRangeBody extends StatelessWidget {
  const _DateRangeBody({required this.presets, required this.selected});

  final List<DateRangePreset> presets;
  final DateRange selected;

  Future<void> _pickCustom(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      // The shop's records do not predate the app by more than a few years,
      // and a picker that scrolls to 1900 buries the dates that matter.
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: selected.from == null || selected.to == null
          ? null
          : DateTimeRange(
              start: AppDateUtils.fromMs(selected.from!),
              end: AppDateUtils.fromMs(selected.to!),
            ),
    );

    if (picked == null || !context.mounted) return;
    Navigator.of(context).pop(DateRange.days(picked.start, picked.end));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final preset in presets)
          AppListRow(
            title: preset.label,
            subtitle: preset.range.isAll
                ? null
                : describeRange(preset.range, const []),
            trailing: [
              if (preset.range == selected)
                Icon(Icons.check_rounded, size: 20, color: palette.brand),
            ],
            onTap: () => Navigator.of(context).pop(preset.range),
          ),
        const RowDivider(full: true),
        AppListRow(
          title: 'Custom range',
          subtitle: 'Pick a start and an end date',
          trailing: [
            Icon(
              Icons.calendar_month_rounded,
              size: 20,
              color: palette.inkSubtle,
            ),
          ],
          onTap: () => _pickCustom(context),
        ),
      ],
    );
  }
}

/// The trigger that sits above a list, showing the window it is currently
/// showing. Compact on purpose — it is a statement of what you are looking at,
/// not a control competing with the search box next to it.
class DateRangeChip extends StatelessWidget {
  const DateRangeChip({
    super.key,
    required this.range,
    required this.onTap,
    this.fiscalYear,
  });

  final DateRange range;
  final VoidCallback onTap;
  final FiscalYear? fiscalYear;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = describeRange(
      range,
      buildDateRangePresets(fiscalYear: fiscalYear),
    );
    final filtered = !range.isAll;

    return Material(
      color: filtered ? palette.brandSoft : palette.sunken,
      borderRadius: BorderRadius.circular(AppSizes.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_rounded,
                size: 16,
                color: filtered ? palette.brand : palette.inkMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: filtered ? palette.brand : palette.inkMuted,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.expand_more_rounded,
                size: 16,
                color: filtered ? palette.brand : palette.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
