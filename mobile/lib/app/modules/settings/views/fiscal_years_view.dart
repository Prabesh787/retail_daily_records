import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/nepali_date.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/enums/domain_tone.dart';
import '../../../data/models/fiscal_year.dart';
import '../controllers/fiscal_years_controller.dart';

/// Fiscal years.
///
/// Rarely visited, and load-bearing when it is: every form in the app refuses
/// to save a record whose date falls outside a year, so this is the screen that
/// unblocks that — and it says so at the top when nothing covers today rather
/// than letting the user find out one rejected bill at a time.
class FiscalYearsView extends GetView<FiscalYearsController> {
  const FiscalYearsView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Fiscal years',
      back: true,
      onRefresh: controller.reload,
      floatingAction: AppFab(
        label: 'New year',
        onPressed: () => _add(context),
      ),
      child: Obx(() {
        if (controller.isLoading.value) return const SkeletonRows(count: 3);

        final message = controller.error.value;
        if (message != null) {
          return ErrorView(message: message, onRetry: controller.reload);
        }

        if (controller.isEmpty) {
          return EmptyState(
            icon: Icons.event_note_outlined,
            title: 'No fiscal years yet',
            message: 'Records are filed under a year, so nothing can be saved '
                'until one exists.',
            actionLabel: 'New year',
            onAction: () => _add(context),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!controller.coversToday) ...[
              _Warning(onFix: () => _add(context)),
              AppSizes.gapMd,
            ],
            AppCard.flush(
              child: Column(
                children: [
                  for (var i = 0; i < controller.rows.length; i++) ...[
                    if (i > 0) const RowDivider(),
                    _YearRow(
                      year: controller.rows[i],
                      onActivate: () =>
                          controller.activate(controller.rows[i]),
                      onDelete: () => controller.remove(controller.rows[i]),
                    ),
                  ],
                ],
              ),
            ),
            AppSizes.gapMd,
            Text(
              'One year is active at a time, and new records are filed under '
              'it. Changing which is active does not move anything already '
              'recorded.',
              style: AppTextStyles.caption.copyWith(
                color: context.palette.inkSubtle,
              ),
            ),
            AppSizes.gapXl,
          ],
        );
      }),
    );
  }

  Future<void> _add(BuildContext context) async {
    final draft = await showFiscalYearSheet(context);
    if (draft != null) await controller.create(draft);
  }
}

/// Shown when no year covers today — the state in which the whole app quietly
/// refuses to save anything.
class _Warning extends StatelessWidget {
  const _Warning({required this.onFix});

  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 19,
                color: palette.pending,
              ),
              AppSizes.gapSm,
              Text(
                'No year covers today',
                style: AppTextStyles.bodyStrong.copyWith(
                  color: palette.pending,
                ),
              ),
            ],
          ),
          AppSizes.gapXs,
          Text(
            'Bills, sales and payments dated today cannot be saved until a '
            'year covering it exists.',
            style: AppTextStyles.caption.copyWith(color: palette.inkMuted),
          ),
          AppSizes.gapMd,
          AppOutlinedButton(
            label: 'Add this year',
            icon: Icons.add_rounded,
            expanded: false,
            onPressed: onFix,
          ),
        ],
      ),
    );
  }
}

class _YearRow extends StatelessWidget {
  const _YearRow({
    required this.year,
    required this.onActivate,
    required this.onDelete,
  });

  final FiscalYear year;
  final VoidCallback onActivate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppListRow(
      leading: IconPlate(
        icon: Icons.event_note_rounded,
        color: year.isActive ? palette.brand : palette.inkSubtle,
      ),
      title: year.name,
      subtitle: '${AppDateUtils.formatDate(year.startDate)} — '
          '${AppDateUtils.formatDate(year.endDate)}',
      trailing: [
        if (year.isActive)
          const AppBadge(label: 'Active', tone: DomainTone.success)
        else if (year.isCurrent)
          const AppBadge(label: 'Covers today', tone: DomainTone.info),
      ],
      // Tapping activates; the long-press deletes. Deletion is rare and
      // destructive, so it does not get a button competing with the action
      // anyone actually came here for.
      onTap: year.isActive ? null : onActivate,
      onLongPress: year.isActive ? null : onDelete,
    );
  }
}

/// Collects a new fiscal year.
///
/// Defaults to the Nepali year containing today, because that is what is being
/// added almost every time — and keying 2083-04-01 by hand is exactly the sort
/// of thing that goes wrong once and then files a year of records in the wrong
/// place.
Future<FiscalYear?> showFiscalYearSheet(BuildContext context) {
  return AppSheet.show<FiscalYear>(
    context: context,
    title: 'New fiscal year',
    child: const _FiscalYearForm(),
  );
}

class _FiscalYearForm extends StatefulWidget {
  const _FiscalYearForm();

  @override
  State<_FiscalYearForm> createState() => _FiscalYearFormState();
}

class _FiscalYearFormState extends State<_FiscalYearForm> {
  late final ({String name, int start, int end}) _suggested = _suggest();

  late final TextEditingController _name =
      TextEditingController(text: _suggested.name);
  late int _start = _suggested.start;
  late int _end = _suggested.end;

  /// The Nepali year containing today, as a name and a date range.
  ///
  /// A BS year runs Baisakh 1 to Chaitra end, so the range is derived from the
  /// conversion rather than assumed to be a fixed number of days — the months
  /// vary in length and the years do too.
  ({String name, int start, int end}) _suggest() {
    final todayBs = NepaliDate.msToBs(AppDateUtils.startOfTodayMs());
    final year = int.tryParse(todayBs?.split('-').first ?? '') ?? 2082;

    final start = NepaliDate.bsToMs('$year-01-01');
    final nextStart = NepaliDate.bsToMs('${year + 1}-01-01');

    return (
      name: '$year/${(year + 1) % 100}',
      start: start ?? AppDateUtils.startOfTodayMs(),
      // The day before the next year opens, so the two meet with no gap and no
      // overlap — a record dated on the boundary must land in exactly one.
      end: (nextStart ?? AppDateUtils.startOfTodayMs()) - 1,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        0,
        AppSizes.lg,
        AppSizes.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Name',
            controller: _name,
            hint: '2083/84',
            textInputAction: TextInputAction.done,
          ),
          AppSizes.gapMd,
          DateField(
            label: 'Starts',
            value: _start,
            onChanged: (ms) => setState(() => _start = ms),
          ),
          AppSizes.gapMd,
          DateField(
            label: 'Ends',
            value: _end,
            onChanged: (ms) => setState(() => _end = ms),
          ),
          AppSizes.gapLg,
          AppButton(
            label: 'Add year',
            onPressed: () {
              final name = _name.text.trim();
              if (name.isEmpty || _end <= _start) {
                AppToast.error(
                  'A year needs a name, and it has to end after it starts.',
                );
                return;
              }

              Navigator.of(context).pop(
                FiscalYear(
                  id: '',
                  createdAt: 0,
                  updatedAt: 0,
                  name: name,
                  startDate: _start,
                  endDate: _end,
                  startDateBs: NepaliDate.msToBs(_start),
                  endDateBs: NepaliDate.msToBs(_end),
                  // The first year added becomes active, because an app with
                  // years but none active cannot save anything.
                  isActive: true,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
