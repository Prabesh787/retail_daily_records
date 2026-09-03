import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routes/app_pages.dart';
import '../../../services/auth_service.dart';

/// Everything that does not earn a tab.
///
/// Five tabs is the practical ceiling for a thumb-reachable bar, so the
/// cheque register, customers, fiscal years and shop details live here. Rows
/// that are not built yet are listed and disabled rather than hidden — the menu
/// is also the map of what the app does.
class MoreView extends StatelessWidget {
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
                        auth.accountName.isEmpty ? 'Signed in' : auth.accountName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: palette.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppSizes.gapLg,

          const SectionHeader(title: 'MONEY'),
          AppCard.flush(
            child: AppListRow(
              leading: IconPlate(
                icon: Icons.account_balance_wallet_rounded,
                color: palette.pending,
              ),
              title: 'Cheque register',
              subtitle: 'Cheques written but not yet cleared',
              chevron: true,
              onTap: () => Get.toNamed<void>(Routes.cheques),
            ),
          ),
          AppSizes.gapLg,

          const SectionHeader(title: 'RECORDS'),
          const AppCard.flush(
            child: Column(
              children: [
                _Pending(
                  icon: Icons.people_outline_rounded,
                  title: 'Customers',
                  subtitle: 'Who owes the shop, and their ledgers',
                ),
                RowDivider(),
                _Pending(
                  icon: Icons.event_note_outlined,
                  title: 'Fiscal years',
                  subtitle: 'The year every record is filed under',
                ),
                RowDivider(),
                _Pending(
                  icon: Icons.storefront_outlined,
                  title: 'Shop details',
                  subtitle: 'Name, PAN and address on your paperwork',
                ),
              ],
            ),
          ),
          AppSizes.gapLg,

          AppOutlinedButton(
            label: 'Sign out',
            icon: Icons.logout_rounded,
            onPressed: () async {
              final confirmed = await ConfirmDialog.show(
                title: 'Sign out?',
                message: 'Anything not yet synced stays on this device and '
                    'will go up the next time you sign in.',
                confirmLabel: 'Sign out',
                isDestructive: true,
              );
              if (confirmed) await auth.signOut();
            },
          ),
          AppSizes.gapXl,
        ],
      ),
    );
  }
}

/// A destination that exists in the plan but not yet in the app. Shown so the
/// menu stays an honest map, greyed so it does not promise a tap.
class _Pending extends StatelessWidget {
  const _Pending({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppListRow(
      leading: IconPlate(icon: icon, color: palette.inkSubtle),
      title: title,
      subtitle: subtitle,
      trailing: const [AppBadge(label: 'Soon', dot: false)],
    );
  }
}
