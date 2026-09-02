import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/enums/sync_status.dart';
import '../../../services/sync_service.dart';

/// Tells the shopkeeper exactly what the app is holding.
///
/// Sync that fails quietly is how these apps lose trust: a week later three
/// bills are missing and nobody knows why. "3 pending" on the dashboard costs
/// one line of screen and makes the state legible.
class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({super.key});

  @override
  Widget build(BuildContext context) {
    final service = SyncService.to;

    return Obx(() {
      final state = service.state.value;
      final (color, icon) = switch (state.phase) {
        SyncPhase.syncing => (AppColors.info, Icons.sync),
        SyncPhase.offline => (AppColors.warning, Icons.cloud_off),
        SyncPhase.failed => (AppColors.debit, Icons.error_outline),
        SyncPhase.disabled => (AppColors.textSecondary, Icons.phone_android),
        SyncPhase.idle => state.hasPending
            ? (AppColors.warning, Icons.cloud_upload_outlined)
            : (AppColors.credit, Icons.cloud_done_outlined),
      };

      return InkWell(
        onTap: state.isSyncing ? null : () => service.syncNow(force: true),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                state.label,
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
