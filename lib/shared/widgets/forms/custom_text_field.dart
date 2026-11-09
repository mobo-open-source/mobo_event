import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final String? Function(String?)? validator;
  final bool isDark;
  final bool showBorder;
  final TextInputType? keyboardType;
  final int? maxLines;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;

  const CustomTextField({
    required this.controller,
    required this.labelText,
    this.hintText,
    this.validator,
    this.isDark = false,
    this.showBorder = false,
    this.keyboardType,
    this.maxLines = 1,
    this.suffixIcon,
    this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: TextStyle(
            fontFamily: GoogleFonts.manrope(
              fontWeight: FontWeight.w400,
            ).fontFamily,
            color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
          ),
        ),
        const SizedBox(height: 8),
        // The app's standard field look (see `Field`): filled, radius 12, a
        // 2px brand ring on focus and a red outline with its message beneath
        // on error.
        TextFormField(
          style: AppTheme.fieldValueStyle(isDark),
          cursorColor: AppTheme.primaryColor,
          controller: controller,
          onChanged: onChanged,
          // Shows a required field's message as soon as it is cleared, so a
          // disabled Save next to it never looks unexplained.
          autovalidateMode: AutovalidateMode.onUserInteraction,
          keyboardType: keyboardType ?? TextInputType.text,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTheme.fieldHintStyle(isDark),
            suffixIcon: suffixIcon,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 12,
            ),
            border: _outline(
              showBorder ? _getBorderColor() : AppTheme.restingBorderColor(isDark),
            ),
            enabledBorder: _outline(
              showBorder ? AppTheme.primaryColor : AppTheme.restingBorderColor(isDark),
            ),
            focusedBorder: _outline(AppTheme.primaryColor, width: 2),
            errorBorder: _outline(StatusColors.red),
            focusedErrorBorder: _outline(StatusColors.red, width: 2),
            errorStyle: const TextStyle(color: StatusColors.red, fontSize: 12),
            filled: true,
            fillColor: AppTheme.inputFill(isDark),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Color _getBorderColor() {
    return isDark ? Colors.grey[700]! : Colors.grey[400]!;
  }

  OutlineInputBorder _outline(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
