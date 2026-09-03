/// The widget kit's domain half — the pieces that know what a bill, a sale or a
/// cheque is.
///
/// Kept apart from `widgets.dart` for the same reason the web app splits `ui/`
/// from `domain/`: the generic half must stay free of model imports so it can
/// be reasoned about, restyled and reused without dragging the data layer
/// behind it. A screen imports both; nothing in the generic half imports this.
library;

export 'balance_card.dart';
export 'date_range_sheet.dart';
export 'detail_list.dart';
export 'rows.dart';
export 'status_badge.dart';
