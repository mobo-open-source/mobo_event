import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';

class MoboToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const MoboToggle({
    super.key,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      toggled: value,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: 56,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: value
                ? AppTheme.primaryColor
                : (isDark ? Colors.transparent : AppTheme.primaryColor.withValues(alpha: 0.06)),
            border: Border.all(
              color: value
                  ? AppTheme.primaryColor
                  : (isDark
                      ? Colors.grey[400]!
                      : AppTheme.primaryColor.withValues(alpha: 1)),
              width: 2,
            ),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: 24,
              height: 24,
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? Colors.white : AppTheme.primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// A labelled [MoboToggle] row — the app's take on Odoo's `boolean_toggle`
/// field. Tapping anywhere on the row flips it, like [MoboCheckboxTile].
///
/// [helpLines] (with an optional bold [helpTitle]) add Odoo's small "?" beside
/// the label: tapping it opens a tooltip bubble with the lines as bullets.
/// A null [onChanged] locks the row and dims the switch, for a field Odoo
/// marks readonly. [caption] sits under the row and says why, or what, in a
/// line.
class MoboToggleTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? helpTitle;
  final List<String> helpLines;
  final String? caption;
  final EdgeInsetsGeometry padding;

  const MoboToggleTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.helpTitle,
    this.helpLines = const [],
    this.caption,
    this.padding = const EdgeInsets.symmetric(vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locked = onChanged == null;
    final hasHelp = helpTitle != null || helpLines.isNotEmpty;

    final row = Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimaryOn(isDark),
                  ),
                ),
              ),
              if (hasHelp) _HelpTip(title: helpTitle, lines: helpLines),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // The row handles the tap, so the switch itself stays passive.
        IgnorePointer(
          child: Opacity(
            opacity: locked ? 0.5 : 1,
            child: MoboToggle(value: value, onChanged: onChanged),
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MergeSemantics(
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: locked ? null : () => onChanged!(!value),
            child: Padding(padding: padding, child: row),
          ),
        ),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              caption!,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.secondaryLabelColor(isDark),
              ),
            ),
          ),
      ],
    );
  }
}

/// The "?" beside a label. Tapping it shows a dark bubble — a lighter one on
/// the dark theme, where black would vanish into the card — listing [lines].
class _HelpTip extends StatelessWidget {
  final String? title;
  final List<String> lines;

  const _HelpTip({required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const style = TextStyle(
      fontSize: 12.5,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: Colors.white,
    );

    return Tooltip(
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 8),
      waitDuration: Duration.zero,
      preferBelow: true,
      verticalOffset: 14,
      constraints: const BoxConstraints(maxWidth: 300),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkPopupSurface : AppTheme.dark,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: isDark ? Border.all(color: Colors.white24) : null,
      ),
      textStyle: style,
      richMessage: TextSpan(
        style: style,
        children: [
          if (title != null)
            TextSpan(
              text: title,
              style: style.copyWith(fontWeight: FontWeight.w700),
            ),
          for (var i = 0; i < lines.length; i++)
            // Each bullet starts a line; the first one only needs a break
            // when a title sits above it.
            TextSpan(
              text: '${i == 0 && title == null ? '' : '\n'}• ${lines[i]}',
            ),
        ],
      ),
      // The icon is small; the padding makes it a comfortable tap target.
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedHelpCircle,
          size: 16,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }
}
