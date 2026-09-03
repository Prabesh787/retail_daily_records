import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import '../domain/money.dart';
import '../extensions/context_ext.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_utils.dart';

/// One day's takings.
class TrendPoint {
  const TrendPoint({required this.dateMs, required this.amount});

  final int dateMs;
  final Money amount;
}

/// Daily sales over the last couple of weeks.
///
/// Bars rather than a line: each day is a closed total, not a reading off a
/// continuous signal, and joining them with a slope invents figures for the
/// hours in between. One series, so no legend — the card heading names it.
///
/// Only the day in focus is labelled. A number over every bar is unreadable at
/// phone width, so the figure lives in the header and the chart is scanned for
/// shape; tap a bar for the exact amount. With nothing selected the peak is
/// shown, because "what was my best day" is the question this card is on the
/// dashboard to answer.
class TrendChart extends StatefulWidget {
  const TrendChart({super.key, required this.points, this.height = 96});

  final List<TrendPoint> points;
  final double height;

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  int? _focused;

  @override
  void didUpdateWidget(TrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A refresh can shorten the series; a stale index would read off the end.
    if (_focused != null && _focused! >= widget.points.length) _focused = null;
  }

  int get _peakIndex {
    var peak = 0;
    for (var i = 1; i < widget.points.length; i++) {
      if (widget.points[i].amount > widget.points[peak].amount) peak = i;
    }
    return peak;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final points = widget.points;
    if (points.isEmpty) return const SizedBox.shrink();

    final peak = _peakIndex;
    final shown = _focused ?? peak;
    final maxPaisa = points[peak].amount.paisa;

    // Every bar would be full height on an all-zero week, which reads as a
    // record week rather than an empty one.
    final scale = (maxPaisa <= 0 ? 1 : maxPaisa).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              points[shown].amount.display(decimals: false),
              style: AppTextStyles.amount.copyWith(color: palette.moneyIn),
            ),
            AppSizes.gapSm,
            Text(
              AppDateUtils.formatDateShort(points[shown].dateMs),
              style: AppTextStyles.caption.copyWith(color: palette.inkSubtle),
            ),
          ],
        ),
        AppSizes.gapSm,
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 2px of ground between adjacent bars keeps the marks separate
              // without a gridline doing the job.
              final width =
                  (constraints.maxWidth / points.length - 2).clamp(3.0, 28.0);

              return BarChart(
                BarChartData(
                  maxY: scale,
                  minY: 0,
                  alignment: BarChartAlignment.spaceBetween,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  barTouchData: BarTouchData(
                    // The header is the readout, so the built-in tooltip would
                    // be the same number twice, one of them covering the chart.
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.transparent,
                      getTooltipItem: (_, _, _, _) => null,
                    ),
                    touchCallback: (event, response) {
                      final index = response?.spot?.touchedBarGroupIndex;
                      if (index == null || index < 0) return;
                      if (index != _focused) {
                        setState(() => _focused = index);
                      }
                    },
                  ),
                  barGroups: [
                    for (var i = 0; i < points.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            // A day with no sales still gets a stub, so a gap
                            // reads as "nothing sold" rather than "no data".
                            toY: _barHeight(points[i].amount, scale),
                            width: width,
                            color: palette.moneyIn.withValues(
                              alpha: i == shown ? 1 : 0.35,
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
              );
            },
          ),
        ),
        AppSizes.gapSm,
        // Recessive on purpose: the axis is scaffolding, not data.
        DefaultTextStyle(
          style: AppTextStyles.label.copyWith(
            color: palette.inkSubtle,
            fontWeight: FontWeight.w500,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppDateUtils.formatDateShort(points.first.dateMs)),
              Text('peak ${points[peak].amount.displayShort()}'),
              Text(AppDateUtils.formatDateShort(points.last.dateMs)),
            ],
          ),
        ),
      ],
    );
  }

  /// Bars are scaled against the peak, with a floor so a small day is still a
  /// visible mark rather than a hairline against the baseline.
  double _barHeight(Money amount, double scale) {
    if (amount.paisa <= 0) return scale * 0.02;
    return (amount.paisa / scale).clamp(0.06, 1.0) * scale;
  }
}
