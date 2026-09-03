import 'package:flutter/material.dart';

import '../../data/enums/domain_tone.dart';
import 'app_palette.dart';

/// Turns a [DomainTone] into real colour.
///
/// The enums in `data/enums` name what a status *means* and deliberately do not
/// import Flutter. This is the single place that resolves those names against
/// the palette, so a new payment mode picks up its colour by declaring a tone
/// rather than by someone remembering to add a case to a switch in three
/// different widgets.
extension DomainToneColors on DomainTone {
  /// The foreground: badge text, an icon, a status label.
  Color ink(AppPalette palette) => switch (this) {
        DomainTone.success => palette.moneyIn,
        DomainTone.warning => palette.pending,
        DomainTone.danger => palette.moneyOut,
        DomainTone.info => palette.info,
        DomainTone.neutral => palette.inkMuted,
      };

  /// The tinted ground that belongs with [ink].
  Color ground(AppPalette palette) => switch (this) {
        DomainTone.success => palette.moneyInSoft,
        DomainTone.warning => palette.pendingSoft,
        DomainTone.danger => palette.moneyOutSoft,
        DomainTone.info => palette.infoSoft,
        DomainTone.neutral => palette.neutralSoft,
      };
}

/// Which way the money went.
///
/// A separate axis from [DomainTone] on purpose. "What does this status mean"
/// and "which direction did this figure move" are different questions that
/// happen to share a few colours: a cancelled cheque is neutral *as a status*
/// while the rupees on the same row are still money out. Collapsing the two
/// would force every call site to pick the wrong one half the time.
enum MoneyTone {
  /// Takings — a sale, a receipt.
  inbound,

  /// What the shop spent or still owes.
  outbound,

  /// Handed over, not yet debited.
  pending,

  /// A figure with no direction: a count, a subtotal, a neutral total.
  plain,
}

extension MoneyToneColors on MoneyTone {
  Color ink(AppPalette palette) => switch (this) {
        MoneyTone.inbound => palette.moneyIn,
        MoneyTone.outbound => palette.moneyOut,
        MoneyTone.pending => palette.pending,
        MoneyTone.plain => palette.ink,
      };
}
