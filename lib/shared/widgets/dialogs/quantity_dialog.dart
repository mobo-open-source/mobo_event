import 'package:flutter/material.dart';

import '../forms/mobo_form_field.dart';
import 'common_dialog.dart';

/// Reusable quantity input dialog
class QuantityDialog {
  static Future<double?> show(
    BuildContext context, {
    String title = 'Enter Quantity',
    double initialValue = 1.0,
  }) {
    final controller = TextEditingController(text: initialValue.toString());

    return showDialog<double>(
      context: context,
      // A CommonDialog — whose title and field scroll while Cancel / Confirm
      // stay pinned — rather than an AlertDialog, whose title and buttons can't
      // give way to the keyboard the autofocused field opens (a phone in
      // landscape is left ~100–200dp).
      builder: (ctx) => CommonDialog(
        title: title,
        // The app's standard field look (see `Field`).
        body: MoboTextField(
          controller: controller,
          label: 'Quantity',
          hintText: 'Enter quantity',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        secondaryLabel: 'Cancel',
        onSecondary: () => Navigator.pop(ctx),
        primaryLabel: 'Confirm',
        onPrimary: () {
          final value = double.tryParse(controller.text);
          Navigator.pop(ctx, value);
        },
      ),
    );
  }
}
