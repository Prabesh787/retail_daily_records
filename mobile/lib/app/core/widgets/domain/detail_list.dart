import 'package:flutter/material.dart';

import '../../constants/app_sizes.dart';
import '../../extensions/context_ext.dart';
import '../../theme/app_text_styles.dart';
import '../app_card.dart';
import '../app_list_row.dart';

/// One label/value line in a [DetailList].
class DetailRow {
  const DetailRow(this.label, this.value, {this.mono = false, this.trailing});

  final String label;

  /// Null or empty drops the row entirely — see [DetailList].
  final String? value;

  /// Tabular figures, for a bill number, a PAN, a cheque number: things read
  /// character by character and often compared down a column.
  final bool mono;

  /// Replaces the text value — a badge, usually.
  final Widget? trailing;
}

/// The label/value card every detail screen is built from.
///
/// Rows with no value are dropped rather than rendered blank, so an optional
/// field costs nothing when it was not filled in. A detail screen padded out
/// with half a dozen em dashes tells the reader the form has many fields; it
/// does not tell them anything about this bill.
class DetailList extends StatelessWidget {
  const DetailList({super.key, required this.rows});

  final List<DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final visible = rows
        .where((row) => row.trailing != null || (row.value ?? '').isNotEmpty)
        .toList();

    if (visible.isEmpty) return const SizedBox.shrink();

    return AppCard.flush(
      child: Column(
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const RowDivider(full: true),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.lg,
                vertical: 11,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visible[i].label,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 13,
                      color: palette.inkMuted,
                    ),
                  ),
                  AppSizes.gapLg,
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: visible[i].trailing ??
                          Text(
                            visible[i].value!,
                            textAlign: TextAlign.right,
                            style: visible[i].mono
                                ? AppTextStyles.mono.copyWith(color: palette.ink)
                                : AppTextStyles.bodyStrong.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: palette.ink,
                                  ),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
