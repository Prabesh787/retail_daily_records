import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import '../extensions/context_ext.dart';

/// Drives the shimmer for everything beneath it.
///
/// One [AnimationController] for a whole loading screen rather than one per
/// placeholder: a dozen independent tickers would each schedule their own frame
/// and, worse, drift out of phase, so the sweep would read as a dozen separate
/// flickers instead of one pass of light across the list.
///
/// The animation is handed down the tree rather than its *value*, so this
/// inherited widget never notifies — only the leaf boxes repaint.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ShimmerScope(sweep: _controller, child: widget.child);
}

class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({required this.sweep, required super.child});

  final Animation<double> sweep;

  static Animation<double>? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_ShimmerScope>()
      ?.sweep;

  @override
  bool updateShouldNotify(_ShimmerScope oldWidget) =>
      oldWidget.sweep != sweep;
}

/// A single placeholder bar.
///
/// Falls back to a plain recessed block when there is no [Shimmer] above it, so
/// one used on its own still looks deliberate rather than not drawing at all.
class Skeleton extends StatelessWidget {
  const Skeleton({
    super.key,
    this.height = 13,
    this.width,
    this.widthFactor,
    this.radius = AppSizes.radiusSm,
  });

  /// A square block, for an avatar or an icon plate.
  const Skeleton.square(double size, {super.key, this.radius = AppSizes.radius})
      : height = size,
        width = size,
        widthFactor = null;

  final double height;
  final double? width;

  /// A fraction of the available width, for text lines of uneven length.
  final double? widthFactor;

  final double radius;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sweep = _ShimmerScope.maybeOf(context);
    final shape = BorderRadius.circular(radius);

    Widget box = SizedBox(
      height: height,
      width: width,
      child: sweep == null
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: palette.sunken,
                borderRadius: shape,
              ),
            )
          : AnimatedBuilder(
              animation: sweep,
              builder: (context, _) {
                // The band is one alignment-unit wide and travels from fully
                // off the left edge to fully off the right; outside it the
                // gradient clamps to the recessed colour.
                final t = sweep.value;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: shape,
                    gradient: LinearGradient(
                      begin: Alignment(-2 + 4 * t, 0),
                      end: Alignment(-1 + 4 * t, 0),
                      colors: [palette.sunken, palette.line, palette.sunken],
                    ),
                  ),
                );
              },
            ),
    );

    if (widthFactor != null) {
      box = FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: widthFactor,
        child: box,
      );
    }

    return box;
  }
}

/// Placeholders shaped like the rows that are coming.
///
/// A grey blob says "something is happening"; blocks in the shape of an avatar,
/// two lines and an amount say "a list of parties is happening", and the real
/// rows then land without the layout jumping.
class SkeletonRows extends StatelessWidget {
  const SkeletonRows({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.lg,
                vertical: 14,
              ),
              child: Row(
                children: [
                  const Skeleton.square(42),
                  AppSizes.gapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Uneven line lengths, deterministic rather than
                        // random: a rebuild must not reshuffle the placeholder.
                        Skeleton(widthFactor: 0.55 + (i * 13 % 30) / 100),
                        const SizedBox(height: 7),
                        const Skeleton(height: 11, widthFactor: 0.4),
                      ],
                    ),
                  ),
                  AppSizes.gapMd,
                  const Skeleton(width: 64),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
