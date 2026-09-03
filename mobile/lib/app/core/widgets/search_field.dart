import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import '../extensions/context_ext.dart';
import '../theme/app_text_styles.dart';

/// The search box above a list.
///
/// A recessed pill rather than a bordered input: it is a filter over the list
/// below it, not a field being filled in, and giving it the same outline as a
/// form field makes a list screen read like a form.
///
/// Owns a [TextEditingController] when none is supplied, so the common case —
/// a controller holding an `RxString` and reacting to [onChanged] — does not
/// have to create and dispose one just to get a clear button.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    this.controller,
    this.hint = 'Search',
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  TextEditingController? _owned;

  TextEditingController get _controller =>
      widget.controller ?? (_owned ??= TextEditingController());

  @override
  void dispose() {
    // Only ever the one this widget made; disposing the caller's would break
    // the screen that still holds it.
    _owned?.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      decoration: BoxDecoration(
        color: palette.sunken,
        borderRadius: BorderRadius.circular(AppSizes.radius),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 19, color: palette.inkSubtle),
          AppSizes.gapSm,
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: widget.autofocus,
              onChanged: widget.onChanged,
              textInputAction: TextInputAction.search,
              style: AppTextStyles.body.copyWith(color: palette.ink),
              cursorColor: palette.brand,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: widget.hint,
                hintStyle: AppTextStyles.body.copyWith(
                  color: palette.inkSubtle,
                ),
                // The field is already inside a filled pill; letting the theme
                // fill it again paints a second, slightly different ground.
                filled: false,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : GestureDetector(
                    onTap: _clear,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(left: AppSizes.sm),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: palette.inkSubtle,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
