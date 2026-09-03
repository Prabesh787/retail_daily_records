import 'package:flutter/material.dart';

import '../../../data/enums/payment_status.dart';
import '../../../data/enums/sale_payment_mode.dart';
import '../../../data/enums/sale_type.dart';
import '../../../data/enums/supplier_payment_mode.dart';
import '../app_badge.dart';

/// Where a payment stands: issued, cleared, cancelled.
///
/// A state that will change, so it keeps the dot.
class PaymentStatusBadge extends StatelessWidget {
  const PaymentStatusBadge(this.status, {super.key});

  final PaymentStatus status;

  @override
  Widget build(BuildContext context) =>
      AppBadge(label: status.label, tone: status.tone);
}

/// How the shop paid a supplier: cash, cheque, bank transfer.
///
/// No dot — this is a fact about the row rather than a condition, and giving it
/// the same marker as a status makes the two read as the same kind of thing.
class SupplierPaymentModeBadge extends StatelessWidget {
  const SupplierPaymentModeBadge(this.mode, {super.key});

  final SupplierPaymentMode mode;

  @override
  Widget build(BuildContext context) =>
      AppBadge(label: mode.label, tone: mode.tone, dot: false);
}

/// How a customer settled: cash, bank, cheque, credit.
class SalePaymentModeBadge extends StatelessWidget {
  const SalePaymentModeBadge(this.mode, {super.key});

  final SalePaymentMode mode;

  @override
  Widget build(BuildContext context) =>
      AppBadge(label: mode.label, tone: mode.tone, dot: false);
}

/// Whether a sale was written down as a total or itemised.
class SaleTypeBadge extends StatelessWidget {
  const SaleTypeBadge(this.type, {super.key});

  final SaleType type;

  @override
  Widget build(BuildContext context) =>
      AppBadge(label: type.shortLabel, tone: type.tone, dot: false);
}
