import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class MoboCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double size;
  final double radius;

  const MoboCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 22,
    this.radius = 6,
  });

  @override
  State<MoboCheckbox> createState() => _MoboCheckboxState();
}

class _MoboCheckboxState extends State<MoboCheckbox> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryColor;
    final isDisabled = widget.onChanged == null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: isDisabled
            ? null
            : () => widget.onChanged!(!widget.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(
              color: primary,
              width: 2,
            ),
            color: widget.value
                ? primary
                : (_hovering
                ? primary.withValues(alpha: 0.10)
                : Colors.transparent),
          ),
          child: widget.value
              ? Icon(
                  Icons.check_rounded,
                  size: widget.size * 0.75,
                  color: Colors.white,
                )
              : null,
        ),
      ),
    );
  }
}


/// A [MoboCheckbox] with a label; tapping anywhere on the row toggles it.
/// Replaces Material's CheckboxListTile so every labelled checkbox in the
/// app looks the same. Forms set [checkboxAtEnd] so the label sits on the
/// left like their other fields; lists keep the box leading.
class MoboCheckboxTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final EdgeInsetsGeometry padding;
  final bool checkboxAtEnd;

  const MoboCheckboxTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(vertical: 10),
    this.checkboxAtEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = Expanded(
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimaryOn(isDark),
        ),
      ),
    );
    // The row handles the tap, so the box itself stays passive.
    final box = IgnorePointer(
      child: MoboCheckbox(value: value, onChanged: onChanged),
    );
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: padding,
        child: Row(
          children: checkboxAtEnd
              ? [label, const SizedBox(width: 12), box]
              : [box, const SizedBox(width: 12), label],
        ),
      ),
    );
  }
}
