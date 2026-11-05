import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/enums/document_type.dart';
import '../../../data/models/supplier.dart';
import '../controllers/gallery_controller.dart';

/// Photos of the paper, for finding a bill without first remembering which
/// record it was filed against.
///
/// Owns its scrolling: a shop collects hundreds of these, and a lazy grid only
/// decodes the photos actually on screen.
class GalleryView extends GetView<GalleryController> {
  const GalleryView({super.key});

  static const List<Segment<AttachmentEntityType>> _kinds = [
    Segment(value: AttachmentEntityType.purchase, label: 'Bills'),
    Segment(value: AttachmentEntityType.supplierPayment, label: 'Receipts'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Bill gallery',
      back: true,
      padded: false,
      scrollable: false,
      onRefresh: controller.reload,
      headerExtraHeight: 112,
      headerExtra: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedControl<AttachmentEntityType>(
              segments: _kinds,
              value: controller.kind.value,
              onChanged: controller.setKind,
            ),
            AppSizes.gapSm,
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _SupplierChip(
                    supplier: controller.supplier.value,
                    onTap: () => _pickSupplier(context),
                  ),
                  AppSizes.gapSm,
                  DateRangeChip(
                    range: controller.range.value,
                    onTap: () => _pickRange(context),
                  ),
                  if (controller.isFiltered) ...[
                    AppSizes.gapXs,
                    TextButton(
                      onPressed: controller.clearFilters,
                      child: const Text('Clear'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      child: Obx(() {
        if (controller.isLoading.value) return const SkeletonRows();

        final message = controller.error.value;
        if (message != null) {
          return ErrorView(message: message, onRetry: controller.reload);
        }

        final isFiltered = controller.isFiltered;
        final paper = controller.showingBills ? 'bills' : 'receipts';

        return CustomScrollView(
          // Always scrollable, so pull-to-refresh works on a short list too.
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (controller.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.photo_library_outlined,
                  title: isFiltered
                      ? 'No $paper match'
                      : 'No photos of $paper yet',
                  message: isFiltered
                      ? 'Try another supplier or a wider date range.'
                      : controller.showingBills
                      ? 'Add a photo when you record a bill, and it will '
                            'appear here under its supplier.'
                      : 'Add a photo when you record a payment, and it will '
                            'appear here under its supplier.',
                  actionLabel: isFiltered ? 'Clear filters' : null,
                  onAction: isFiltered ? controller.clearFilters : null,
                ),
              )
            else
              for (final group in controller.groups) ...[
                SliverToBoxAdapter(
                  child: _SupplierHeader(
                    name: group.supplierName,
                    count: group.items.length,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: AppSizes.sm,
                          mainAxisSpacing: AppSizes.md,
                          mainAxisExtent: 176,
                        ),
                    itemCount: group.items.length,
                    itemBuilder: (context, index) {
                      final item = group.items[index];
                      return _ScanTile(
                        item: item,
                        onTap: () => controller.open(item),
                      );
                    },
                  ),
                ),
              ],
            const SliverToBoxAdapter(child: AppSizes.gapXl),
          ],
        );
      }),
    );
  }

  Future<void> _pickSupplier(BuildContext context) async {
    final picked = await showPickerSheet<Supplier>(
      context: context,
      title: 'Filter by supplier',
      hint: 'Name or phone',
      search: controller.searchSuppliers,
      emptyTitle: 'No suppliers match',
      itemBuilder: (supplier, select) =>
          SupplierRow(supplier: supplier, onTap: select),
    );
    if (picked != null) controller.setSupplier(picked);
  }

  Future<void> _pickRange(BuildContext context) async {
    final picked = await showDateRangeSheet(
      context: context,
      selected: controller.range.value,
    );
    if (picked != null) controller.setRange(picked);
  }
}

/// The supplier counterpart of [DateRangeChip], so the two read as one row.
class _SupplierChip extends StatelessWidget {
  const _SupplierChip({required this.supplier, required this.onTap});

  final Supplier? supplier;
  final VoidCallback onTap;

  static const double _maxWidth = 180;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final filtered = supplier != null;
    final color = filtered ? palette.brand : palette.inkMuted;

    return Material(
      color: filtered ? palette.brandSoft : palette.sunken,
      borderRadius: BorderRadius.circular(AppSizes.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: 10,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storefront_rounded, size: 16, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    supplier?.name ?? 'All suppliers',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.expand_more_rounded, size: 16, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SupplierHeader extends StatelessWidget {
  const _SupplierHeader({required this.name, required this.count});

  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyStrong.copyWith(color: palette.ink),
            ),
          ),
          AppSizes.gapSm,
          Text(
            '$count photo${count == 1 ? '' : 's'}',
            style: AppTextStyles.caption.copyWith(color: palette.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _ScanTile extends StatelessWidget {
  const _ScanTile({required this.item, required this.onTap});

  final GalleryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radius),
              child: ColoredBox(
                color: palette.sunken,
                child: ScanThumbnail(scan: item.scan),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.record.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
          Text(
            AppDateUtils.formatDateShort(item.record.recordDate),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(color: palette.inkMuted),
          ),
        ],
      ),
    );
  }
}
