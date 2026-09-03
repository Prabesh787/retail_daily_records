import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import 'app_sheet.dart';
import 'empty_state.dart';
import 'search_field.dart';
import 'skeleton.dart';

/// Picks one record out of a searchable list.
///
/// A sheet rather than a `DropdownButton`, and the difference is not cosmetic:
/// a shop with two hundred suppliers cannot be asked to scroll a menu, and a
/// menu cannot be searched. The choice is also being made *about* something on
/// the form behind it, which a sheet keeps visible.
///
/// [search] is called with the query and re-queries the database rather than
/// filtering a list held in memory — the same rule the list screens follow, so
/// a picker cannot show a supplier the list would not.
Future<T?> showPickerSheet<T>({
  required BuildContext context,
  required String title,
  required Future<List<T>> Function(String query) search,
  required Widget Function(T item, VoidCallback select) itemBuilder,
  String hint = 'Search',
  String emptyTitle = 'Nothing found',
  String emptyMessage = 'Try a different spelling.',
  Widget? footer,
}) {
  return AppSheet.show<T>(
    context: context,
    title: title,
    child: _PickerBody<T>(
      search: search,
      itemBuilder: itemBuilder,
      hint: hint,
      emptyTitle: emptyTitle,
      emptyMessage: emptyMessage,
      footer: footer,
    ),
  );
}

class _PickerBody<T> extends StatefulWidget {
  const _PickerBody({
    required this.search,
    required this.itemBuilder,
    required this.hint,
    required this.emptyTitle,
    required this.emptyMessage,
    this.footer,
  });

  final Future<List<T>> Function(String query) search;
  final Widget Function(T item, VoidCallback select) itemBuilder;
  final String hint;
  final String emptyTitle;
  final String emptyMessage;
  final Widget? footer;

  @override
  State<_PickerBody<T>> createState() => _PickerBodyState<T>();
}

class _PickerBodyState<T> extends State<_PickerBody<T>> {
  List<T>? _results;
  Timer? _debounce;

  /// Guards against a slow early query landing after a faster later one and
  /// overwriting it — the classic way a search box ends up showing results for
  /// a query the user has already moved on from.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _run('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _run(String query) async {
    final generation = ++_generation;
    final results = await widget.search(query);
    if (!mounted || generation != _generation) return;
    setState(() => _results = results);
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _run(query));
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            0,
            AppSizes.lg,
            AppSizes.sm,
          ),
          child: SearchField(hint: widget.hint, onChanged: _onChanged),
        ),

        if (results == null)
          const SkeletonRows(count: 4)
        else if (results.isEmpty)
          EmptyState(
            icon: Icons.search_off_rounded,
            title: widget.emptyTitle,
            message: widget.emptyMessage,
          )
        else
          for (final item in results)
            widget.itemBuilder(
              item,
              () => Navigator.of(context).pop<T>(item),
            ),

        ?widget.footer,
      ],
    );
  }
}
