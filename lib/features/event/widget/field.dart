import 'package:flutter/material.dart';

class Field extends StatefulWidget {
  final String hint;
  final TextEditingController? controller;
  final TextInputType keyboard;
  final bool enabled;
  final bool readOnly;
  final FocusNode? focusNode;
  final Widget? suffixIcon;

  const Field({
    super.key,
    required this.hint,
    this.controller,
    this.keyboard = TextInputType.text,
    this.enabled = true,
    this.readOnly = false,
    this.focusNode,
    this.suffixIcon,
  });

  @override
  State<Field> createState() => _FieldState();
}

class _FieldState extends State<Field> {
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      keyboardType: widget.keyboard,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      decoration: InputDecoration(
        hintText: widget.hint,
        filled: true,
        fillColor: const Color(0xFFF1F3F5),
        suffixIcon: widget.suffixIcon,
        hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
