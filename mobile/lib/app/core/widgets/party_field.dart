import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import '../extensions/context_ext.dart';
import '../theme/app_text_styles.dart';
import 'app_card.dart';

/// A form slot holding a record chosen from a picker.
///
/// Not a `TextFormField`, so it carries its own label and its own error line
/// rather than borrowing one — which is why this exists as a widget instead of
/// being rebuilt on each form that needs it.
///
/// The [subtitle] is the point of it. A picked supplier shows what is currently
/// owed, a picked bill shows what is left on it: the context that decides
/// whether the amount about to be typed is the right one. A slot that shows
/// only a name makes the user leave the form to find that out.
class PartyField extends StatelessWidget {
  const PartyField({
    super.key,
    required this.label,
    required this.icon,
    required this.placeholder,
    this.title,
    this.subtitle,
    this.subtitleColor,
    this.avatarName,
    this.error,
    this.enabled = true,
    this.onTap,
    this.onClear,
  });

  final String label;

  /// Shown when nothing is chosen yet.
  final IconData icon;
  final String placeholder;

  final String? title;
  final String? subtitle;
  final Color? subtitleColor;

  /// When set and a [title] is chosen, the initials plate replaces [icon].
  final String? avatarName;

  final String? error;
  final bool enabled;
  final VoidCallback? onTap;

  /// Present only on an optional slot that currently holds something.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final invalid = error != null;
    final chosen = title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: palette.inkMuted),
        ),
        AppSizes.gapXs,
        Material(
          color: enabled ? palette.sunken : palette.sunken.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppSizes.radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: AppSizes.control),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.sm,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: invalid ? palette.moneyOut : palette.line,
                  width: invalid ? 1.6 : 1,
                ),
                borderRadius: BorderRadius.circular(AppSizes.radius),
              ),
              child: Row(
                children: [
                  if (chosen != null && avatarName != null)
                    AppAvatar(name: avatarName!, size: 34)
                  else
                    Icon(icon, size: 20, color: palette.inkSubtle),
                  AppSizes.gapMd,
                  Expanded(
                    child: chosen == null
                        ? Text(
                            placeholder,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body.copyWith(
                              color: palette.inkSubtle,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                chosen,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyStrong.copyWith(
                                  color: palette.ink,
                                ),
                              ),
                              if (subtitle != null)
                                Text(
                                  subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption.copyWith(
                                    color: subtitleColor ?? palette.inkMuted,
                                  ),
                                ),
                            ],
                          ),
                  ),
                  if (onClear != null)
                    IconButton(
                      tooltip: 'Clear',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: palette.inkSubtle,
                      ),
                      onPressed: onClear,
                    )
                  else
                    Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: palette.inkSubtle,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (invalid)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: AppSizes.xs),
            child: Text(
              error!,
              style: AppTextStyles.caption.copyWith(color: palette.moneyOut),
            ),
          ),
      ],
    );
  }
}
