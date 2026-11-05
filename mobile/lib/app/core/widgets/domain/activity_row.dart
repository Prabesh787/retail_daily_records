import 'package:flutter/material.dart';

import '../../../data/enums/domain_tone.dart';
import '../../../data/enums/payment_status.dart';
import '../../../data/models/ledger.dart';
import '../../extensions/context_ext.dart';
import '../../utils/date_utils.dart';
import '../app_badge.dart';
import '../app_list_row.dart';
import '../app_card.dart';
import '../../theme/tone_colors.dart';
import 'txn_form.dart';

/// One row on the History tab and the home screen: what it was, who it was
/// with, how much, and where it stands.
class ActivityRow extends StatelessWidget {
  const ActivityRow({super.key, required this.item, this.onTap});

  final ActivityItem item;
  final VoidCallback? onTap;

  String get _party => item.partyName ?? switch (item.kind) {
    ActivityKind.sale => 'Walk-in',
    _ => 'Unknown party',
  };

  String get _title {
    final number = item.docNo;
    final kind = item.kind.label;
    return number == null || number.isEmpty ? kind : '$kind #$number';
  }

  /// Where the document stands, in words a new user can read. A settled payment
  /// needs no badge at all; only a cheque can still change.
  (String, DomainTone)? get _standing {
    if (item.status == PaymentStatus.cancelled) {
      return ('Cancelled', DomainTone.neutral);
    }
    if (item.status == PaymentStatus.issued) {
      return ('Cheque pending', DomainTone.warning);
    }
    if (!item.isDocument) return null;

    if (item.due.isZero) return ('Paid', DomainTone.success);
    if (item.paid.isPositive) return ('Part paid', DomainTone.warning);
    return ('Unpaid', DomainTone.danger);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final standing = _standing;

    return AppListRow(
      leading: IconPlate(
        icon: item.kind.icon,
        color: item.kind.color(palette),
        size: 36,
      ),
      title: _party,
      subtitle: '$_title · ${AppDateUtils.relativeDay(item.dateMs)}',
      trailing: [
        RowAmount(
          item.amount.display(decimals: false),
          tone: item.status == PaymentStatus.cancelled
              ? MoneyTone.plain
              : item.kind.isMoneyIn
              ? MoneyTone.inbound
              : MoneyTone.outbound,
        ),
        if (standing != null)
          AppBadge(label: standing.$1, tone: standing.$2, dot: false),
      ],
      onTap: onTap,
    );
  }
}
