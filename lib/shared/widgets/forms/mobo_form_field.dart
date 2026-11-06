/// The shared form-field kit used by the other Mobo apps (ported from
/// mobo_todo), adapted to this app's AppTheme. Its main job here is
/// [MoboFieldShell], the silhouette every select field shares; this app's
/// forms label their fields with FieldLabel and pass no `label` to the kit.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A field label with a red bold `*` when the field is required — the same
/// grey 14px label as this app's FieldLabel, so a kit field labelled here
/// sits in a form without standing out.
///
/// The star is part of the label rather than appended to the hint, so it is
/// visible before the user touches the field — which is the point of marking
/// something required.
class MoboFieldLabel extends StatelessWidget {
  final String text;
  final bool isRequired;

  /// Bold when the field is the emphasised one on its card (§2).
  final bool emphasized;

  const MoboFieldLabel(
    this.text, {
    super.key,
    this.isRequired = false,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = AppTheme.fieldLabelStyle(isDark);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      // Text.rich, not a bare RichText — see FieldLabel's own note. A style
      // with no fontFamily set (every field label's) falls back to the
      // platform default under RichText instead of the app's Manrope.
      child: Text.rich(
        TextSpan(
          text: text,
          style: emphasized ? base.copyWith(fontWeight: FontWeight.bold) : base,
          children: [
            if (isRequired)
              const TextSpan(
                text: ' *',
                style: TextStyle(
                  color: StatusColors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The standard text field (§6): a filled container with a transparent
/// border that turns red on error, a 12px radius, and its error message as
/// plain text *below* the field.
///
/// Deliberately does not use `InputDecoration.errorText`: drawing the border
/// on the container keeps an invalid field to one outline, and the message
/// below never changes the field's own height.
class MoboTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final bool isRequired;
  final String? hintText;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final int? maxLines;
  final int? minLines;
  final bool readOnly;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final AutovalidateMode? autovalidateMode;
  final VoidCallback? onTap;
  final bool autofocus;

  /// How much of the scroll view around the field is kept clear of the caret
  /// when it scrolls the field into view — what the keyboard opening does.
  /// The default is Flutter's own; raise the bottom for a form with a footer
  /// that floats over the scroll view instead of sitting beneath it.
  final EdgeInsets scrollPadding;

  const MoboTextField({
    super.key,
    this.controller,
    this.label,
    this.isRequired = false,
    this.hintText,
    this.validator,
    this.focusNode,
    this.maxLines = 1,
    this.minLines,
    this.readOnly = false,
    this.keyboardType,
    this.onChanged,
    this.suffixIcon,
    this.prefixIcon,
    this.autovalidateMode,
    this.onTap,
    this.autofocus = false,
    this.scrollPadding = const EdgeInsets.all(20),
  });

  @override
  State<MoboTextField> createState() => _MoboTextFieldState();
}

class _MoboTextFieldState extends State<MoboTextField> {
  FocusNode? _internalFocusNode;
  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          MoboFieldLabel(widget.label!, isRequired: widget.isRequired),

        FormField<String>(
          initialValue: widget.controller?.text ?? '',
          validator: widget.validator,
          autovalidateMode:
              widget.autovalidateMode ?? AutovalidateMode.onUserInteraction,
          builder: (field) {
            final hasError = field.hasError;
            final borderColor = hasError
                ? StatusColors.red
                : (_focusNode.hasFocus
                      ? AppTheme.primaryColor
                      : AppTheme.restingBorderColor(isDark));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppTheme.inputFill(isDark),
                    border: Border.all(
                      color: borderColor,
                      // Same 2px ring as `Field` and the select shell.
                      width: hasError || _focusNode.hasFocus ? 2 : 1,
                    ),
                  ),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    autofocus: widget.autofocus,
                    scrollPadding: widget.scrollPadding,
                    readOnly: widget.readOnly,
                    onTap: widget.onTap,
                    maxLines: widget.maxLines,
                    minLines: widget.minLines,
                    keyboardType: widget.keyboardType,
                    onChanged: (value) {
                      field.didChange(value);
                      widget.onChanged?.call(value);
                    },
                    cursorColor: AppTheme.primaryColor,
                    // The app's field typography, so this matches `Field`.
                    style: AppTheme.fieldValueStyle(isDark),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      hintText: widget.hintText,
                      hintStyle: AppTheme.fieldHintStyle(isDark),
                      prefixIcon: widget.prefixIcon,
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 0,
                      ),
                      suffixIcon: widget.suffixIcon,
                      // Every border is cleared so the Container above is the
                      // only thing drawing one.
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),

                // §6 — the message sits below the field as plain text, so the
                // field itself never changes height when it appears.
                if (hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      field.errorText!,
                      style: const TextStyle(
                        color: StatusColors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// A tappable field shell that looks like the form's text fields but hosts
/// arbitrary content — chips, a placeholder, a trailing chevron.
///
/// Used by the select fields so every control on a form shares one
/// silhouette: the same fill, radius and minimum height as `Field`.
class MoboFieldShell extends StatelessWidget {
  final String? label;
  final bool isRequired;
  final VoidCallback? onTap;
  final Widget child;
  final String? errorText;

  /// Draws the primary focus border. Controls that manage their own
  /// open/closed state (a select's panel) pass this instead of relying on a
  /// [FocusNode].
  final bool isFocused;

  const MoboFieldShell({
    super.key,
    required this.child,
    this.label,
    this.isRequired = false,
    this.onTap,
    this.errorText,
    this.isFocused = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasError = errorText != null;

    final Color borderColor = hasError
        ? StatusColors.red
        : isFocused
        ? AppTheme.primaryColor
        : AppTheme.restingBorderColor(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) MoboFieldLabel(label!, isRequired: isRequired),
        // The fill lives on its own Material so the tap ripple draws on top
        // of it; a filled Container inside the InkWell would paint over the
        // ripple, and an Ink fill would sink beneath the forms' coloured
        // cards.
        SizedBox(
          width: double.infinity,
          child: Material(
            color: AppTheme.inputFill(isDark),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: borderColor,
                // Same 2px ring as `Field` when it has focus.
                width: hasError || isFocused ? 2 : 1,
              ),
            ),
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              errorText!,
              style: const TextStyle(color: StatusColors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
