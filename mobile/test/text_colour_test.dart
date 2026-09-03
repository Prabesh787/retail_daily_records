import 'package:billrecord/app/core/theme/app_theme.dart';
import 'package:billrecord/app/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Text that is present but invisible.
///
/// Flutter paints text **white** when no colour is resolved anywhere in its
/// chain. `AppTextStyles` carry no colour on purpose — they are shapes, so the
/// same shape can be inked differently in different places — which means any
/// slot that drops the theme's colour renders white on a white card.
///
/// The whole 203-test suite missed exactly this: `find.text` matches a widget
/// regardless of what colour it is painted, so a form whose every label was
/// invisible passed its mount test. These assert the colour itself.
void main() {
  /// Resolves what a `Text` will actually be painted, the way the framework
  /// does: the widget's own style merged onto the ambient default.
  Color? paintedColour(WidgetTester tester, String text) {
    final widget = tester.widget<Text>(find.text(text));
    final ambient = DefaultTextStyle.of(
      tester.element(find.text(text)),
    ).style;

    final style = widget.style;
    if (style == null) return ambient.color;
    return style.inherit ? ambient.merge(style).color : style.color;
  }

  Future<void> pump(WidgetTester tester, ThemeData theme, Widget child) =>
      tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(body: Padding(padding: const EdgeInsets.all(8), child: child)),
        ),
      );

  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    group(name, () {
      testWidgets('a field label is painted, not left to default white',
          (tester) async {
        await pump(
          tester,
          theme,
          AppTextField(label: 'Customer name', controller: null),
        );

        final colour = paintedColour(tester, 'Customer name');
        expect(colour, isNotNull, reason: 'no colour resolved — paints white');
        expect(
          colour,
          isNot(const Color(0xFFFFFFFF)),
          reason: 'invisible on a light card',
        );
      });

      testWidgets('the theme resolves a body colour', (tester) async {
        // The slot every plain `Text` falls back to. It was being replaced with
        // a colourless style, which is what made the form labels disappear.
        expect(theme.textTheme.bodyMedium?.color, isNotNull);
        expect(theme.textTheme.bodyLarge?.color, isNotNull);
        expect(theme.textTheme.titleMedium?.color, isNotNull);
        expect(theme.textTheme.headlineSmall?.color, isNotNull);
        expect(theme.textTheme.bodySmall?.color, isNotNull);
        expect(theme.textTheme.labelSmall?.color, isNotNull);
      });

      testWidgets('a plain Text inherits a real colour', (tester) async {
        await pump(tester, theme, const Text('Plain'));

        final colour = paintedColour(tester, 'Plain');
        expect(colour, isNotNull);
      });
    });
  }
}
