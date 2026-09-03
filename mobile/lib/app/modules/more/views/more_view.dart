import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routes/app_pages.dart';
import '../../../services/auth_service.dart';
import '../../dashboard/widgets/sync_status_chip.dart';
import '../controllers/more_controller.dart';

/// Everything that does not earn a tab.
///
/// Five tabs is the practical ceiling for a thumb-reachable bar, so the cheque
/// register, customers, fiscal years and shop details live here — along with
/// the two things every app needs somewhere and nowhere in particular: the
/// theme, and the way out.
class MoreView extends GetView<MoreController> {
  const MoreView({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final auth = AuthService.to;

    return AppScreen(
      title: 'More',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Row(
              children: [
                AppAvatar(name: auth.shopName, size: 46),
                AppSizes.gapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.title.copyWith(color: palette.ink),
                      ),
                      Text(
                        auth.accountName.isEmpty
                            ? 'Signed in'
                            : auth.accountName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: palette.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Where the sync state belongs: here and the dashboard are the
                // two places someone goes to ask whether their records have
                // actually left the phone. The chip reports nothing when there
                // is no sync service, so it needs no guard here.
                const SyncStatusChip(),
              ],
            ),
          ),
          AppSizes.gapLg,

          const SectionHeader(title: 'MONEY'),
          AppCard.flush(
            child: Column(
              children: [
                AppListRow(
                  leading: IconPlate(
                    icon: Icons.account_balance_wallet_rounded,
                    color: palette.pending,
                  ),
                  title: 'Cheque register',
                  subtitle: 'Cheques written but not yet cleared',
                  chevron: true,
                  onTap: () => Get.toNamed<void>(Routes.cheques),
                ),
                const RowDivider(),
                AppListRow(
                  leading: IconPlate(
                    icon: Icons.people_rounded,
                    color: palette.brand,
                  ),
                  title: 'Customers',
                  subtitle: 'The people you invoice',
                  chevron: true,
                  onTap: () => Get.toNamed<void>(Routes.customers),
                ),
              ],
            ),
          ),
          AppSizes.gapLg,

          const SectionHeader(title: 'THIS SHOP'),
          AppCard.flush(
            child: Column(
              children: [
                AppListRow(
                  leading: IconPlate(
                    icon: Icons.storefront_rounded,
                    color: palette.brand,
                  ),
                  title: 'Shop details',
                  subtitle: 'Name, PAN and address on your paperwork',
                  chevron: true,
                  onTap: () => Get.toNamed<void>(Routes.shop),
                ),
                const RowDivider(),
                AppListRow(
                  leading: IconPlate(
                    icon: Icons.event_note_rounded,
                    color: palette.brand,
                  ),
                  title: 'Fiscal years',
                  subtitle: 'The year every record is filed under',
                  chevron: true,
                  onTap: () => Get.toNamed<void>(Routes.fiscalYears),
                ),
              ],
            ),
          ),
          AppSizes.gapLg,

          const SectionHeader(title: 'APPEARANCE'),
          AppCard(
            child: Obx(
              () => SegmentedControl<ThemeMode>(
                segments: const [
                  Segment(value: ThemeMode.light, label: 'Light'),
                  Segment(value: ThemeMode.dark, label: 'Dark'),
                  Segment(value: ThemeMode.system, label: 'System'),
                ],
                value: controller.themeMode.value,
                onChanged: controller.setThemeMode,
              ),
            ),
          ),
          AppSizes.gapLg,

          AppOutlinedButton(
            label: 'Sign out',
            icon: Icons.logout_rounded,
            onPressed: controller.signOut,
          ),
          AppSizes.gapXl,
        ],
      ),
    );
  }
}
