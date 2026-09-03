import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_sizes.dart';
import '../extensions/context_ext.dart';
import '../theme/app_text_styles.dart';

/// The frame every screen in the app is built in.
///
/// One of these per route, so the header, the safe areas and the scroll
/// container are decided once rather than twenty times. The web app's `Screen`
/// does the same job, and keeping the two aligned is what stops the phone and
/// the browser drifting into looking like different products.
///
/// The header carries an optional [eyebrow] above the title — a supplier's name
/// over "Statement", a shop over "Purchases" — because a pushed screen usually
/// needs to say both what it is and what it is about, and two lines of header
/// costs less than a subtitle inside the content.
class AppScreen extends StatelessWidget {
  const AppScreen({
    super.key,
    required this.title,
    required this.child,
    this.eyebrow,
    this.back = false,
    this.actions,
    this.headerExtra,
    this.floatingAction,
    this.padded = true,
    this.scrollable = true,
    this.onRefresh,
    this.bottomBar,
  });

  final String title;

  /// Smaller line above the title, for context the title cannot carry.
  final String? eyebrow;

  /// Shown on a pushed route. A tab body sets this false — there is nothing
  /// behind it to go back to.
  final bool back;

  final List<Widget>? actions;

  /// Pinned under the header and above the scroll area: a search field, a
  /// filter. It does not scroll away, because a list you are filtering is a
  /// list you need the filter for at the bottom too.
  final Widget? headerExtra;

  final Widget? floatingAction;

  /// Pinned to the bottom — a Save button that must stay reachable however long
  /// the form is.
  final Widget? bottomBar;

  final Widget child;

  /// False for a screen that owns its own scrolling, which is every long list:
  /// a `ListView` inside a `SingleChildScrollView` builds every row at once and
  /// throws away the one thing a list view is for.
  final bool scrollable;

  final bool padded;

  /// Pull to refresh. Given on any screen backed by a query the user might
  /// reasonably think is stale.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget body = child;

    if (scrollable) {
      body = SingleChildScrollView(
        // Always scrollable, so pull-to-refresh works even when the content is
        // shorter than the screen.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padded ? AppSizes.pagePadding : EdgeInsets.zero,
        child: child,
      );
    } else if (padded) {
      body = Padding(padding: AppSizes.pagePadding, child: child);
    }

    if (onRefresh != null) {
      body = RefreshIndicator(
        onRefresh: onRefresh!,
        color: palette.brand,
        backgroundColor: palette.surface,
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: back ? 0 : AppSizes.lg,
        leading: back
            ? IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.chevron_left_rounded, size: 28),
                onPressed: () => Get.back<void>(),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (eyebrow != null && eyebrow!.isNotEmpty)
              Text(
                eyebrow!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label.copyWith(color: palette.inkSubtle),
              ),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.title.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: palette.ink,
              ),
            ),
          ],
        ),
        actions: actions,
        // The hairline appears only once content has passed under the header —
        // the small detail that makes a header read as pinned rather than as a
        // band of colour.
        bottom: headerExtra == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.lg,
                    0,
                    AppSizes.lg,
                    AppSizes.md,
                  ),
                  child: headerExtra,
                ),
              ),
      ),
      body: SafeArea(top: false, child: body),
      floatingActionButton: floatingAction,
      bottomNavigationBar: bottomBar == null
          ? null
          : SafeArea(
              top: false,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.surface,
                  border: Border(top: BorderSide(color: palette.line)),
                ),
                child: Padding(
                  padding: AppSizes.pagePadding,
                  child: bottomBar,
                ),
              ),
            ),
    );
  }
}
