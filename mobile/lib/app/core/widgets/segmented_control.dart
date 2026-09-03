import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import '../extensions/context_ext.dart';
import '../theme/app_text_styles.dart';

/// One option in a [SegmentedControl].
class Segment<T> {
  const Segment({required this.value, required this.label});

  final T value;
  final String label;
}

/// The iOS-style filter switch above a list — All / Unpaid / Cheques.
///
/// The selected thumb slides rather than cutting, because the movement is what
/// tells you which way you went through a small set of options; a thumb that
/// teleports leaves you re-reading the labels to find out where you landed.
///
/// Generic over the value so a screen switches on an enum and gets exhaustive
/// checking, instead of comparing strings.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final List<Segment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final count = segments.length;
    final selected = segments.indexWhere((s) => s.value == value);

    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.sunken,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Stack(
        children: [
          // Positioned by fraction rather than by measured pixels, so the thumb
          // stays put through a rotation or a font-scale change without a
          // relayout pass of its own.
          if (selected >= 0)
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment(
                count == 1 ? 0 : (selected / (count - 1)) * 2 - 1,
                0,
              ),
              child: FractionallySizedBox(
                widthFactor: 1 / count,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                    boxShadow: AppSizes.card(palette.shadow),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              for (final segment in segments)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(segment.value),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: segment.value == value
                              ? palette.ink
                              : palette.inkMuted,
                        ),
                        child: Text(
                          segment.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
