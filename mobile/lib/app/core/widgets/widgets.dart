/// The shared widget kit.
///
/// A screen imports this one file rather than a dozen relative paths, which is
/// what keeps a view's import block about the screen's own dependencies —
/// its controller, its models — instead of burying them under boilerplate.
///
/// `MoneyTone` and the `DomainTone` colour resolution ride along because every
/// widget here that shows a figure takes one.
library;

export '../theme/tone_colors.dart' show DomainToneColors, MoneyTone, MoneyToneColors;
export '../controllers/loader_controller.dart';
export '../domain/day_group.dart';
export 'app_badge.dart';
export 'app_button.dart';
export 'app_card.dart';
export 'app_fab.dart';
export 'app_list_row.dart';
export 'app_sheet.dart';
export 'date_field.dart';
export 'app_text_field.dart';
export 'app_toast.dart';
export 'confirm_dialog.dart';
export 'app_screen.dart';
export 'empty_state.dart';
export 'party_field.dart';
export 'picker_sheet.dart';
export 'error_view.dart';
export 'loading_view.dart';
export 'search_field.dart';
export 'segmented_control.dart';
export 'skeleton.dart';
export 'stat_tile.dart';
export 'trend_chart.dart';
