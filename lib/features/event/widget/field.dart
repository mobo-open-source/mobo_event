import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

/// The app's standard text field — every text input on a form looks like
/// this (the select fields' shell and MoboTextField match it).
///
/// Mirrors mobo_fleet's vehicle-form field recipe (CLAUDE.md §6): a filled
/// grey background, radius 12 and a 2px brand-coloured focus ring, turning
/// red with its message beneath when [validator] rejects the value. Form
/// fields carry no leading icon — the label above says what they hold.
class Field extends StatefulWidget {
  final String hint;
  final TextEditingController? controller;
  final TextInputType keyboard;
  final bool enabled;
  final bool readOnly;
  final FocusNode? focusNode;
  final Widget? suffixIcon;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  /// Checked as the user types (after their first edit), not only on save.
  final String? Function(String?)? validator;
  final bool autofocus;

  const Field({
    super.key,
    required this.hint,
    this.controller,
    this.keyboard = TextInputType.text,
    this.enabled = true,
    this.readOnly = false,
    this.focusNode,
    this.suffixIcon,
    this.maxLines = 1,
    this.onChanged,
    this.inputFormatters,
    this.validator,
    this.autofocus = false,
  });

  @override
  State<Field> createState() => _FieldState();
}

class _FieldState extends State<Field> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      keyboardType: widget.keyboard,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      maxLines: widget.maxLines,
      onChanged: widget.onChanged,
      inputFormatters: widget.inputFormatters,
      autofocus: widget.autofocus,
      validator: widget.validator,
      autovalidateMode: widget.validator == null
          ? null
          : AutovalidateMode.onUserInteraction,
      cursorColor: AppTheme.primaryColor,
      style: AppTheme.fieldValueStyle(isDark),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: AppTheme.fieldHintStyle(isDark),
        suffixIcon: widget.suffixIcon,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 12,
        ),
        filled: true,
        fillColor: AppTheme.inputFill(isDark),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: AppTheme.restingBorderSide(isDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: AppTheme.restingBorderSide(isDark),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: AppTheme.restingBorderSide(isDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: StatusColors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: StatusColors.red, width: 2),
        ),
        errorStyle: const TextStyle(color: StatusColors.red, fontSize: 12),
      ),
    );
  }
}
