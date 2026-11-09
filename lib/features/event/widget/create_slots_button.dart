import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_theme.dart';

/// "+ Create Slots" under the Multiple Slot toggle in the create and edit
/// event forms.
///
/// A plain text button, the same as the "+ Create Question" under the
/// question picker's options: brand colour, 14/w600, a plus before the label.
/// It has no left padding, so the plus lines up with the toggle's label above.
/// Once the event has slots ([count] > 0) it reads "Manage 3 slots" with a
/// calendar in place of the plus, so the current total is still on show.
///
/// Slots need a saved event, so tapping it first creates or saves the event;
/// while that is under way ([isLoading]) the icon becomes a spinner and taps
/// are ignored.
class CreateSlotsButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  /// Slots the event already has; 0 on a new event.
  final int count;

  const CreateSlotsButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.count = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.primaryColor,
          // A null onPressed (while loading) would otherwise grey the label.
          disabledForegroundColor: AppTheme.primaryColor,
          padding: const EdgeInsets.only(right: 8),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryColor,
                ),
              )
            : HugeIcon(
                icon: count == 0
                    ? HugeIcons.strokeRoundedAdd01
                    : HugeIcons.strokeRoundedCalendar03,
                size: 18,
                color: AppTheme.primaryColor,
              ),
        label: Text(
          count == 0
              ? 'Create Slots'
              : 'Manage $count ${count == 1 ? 'slot' : 'slots'}',
          maxLines: 1,
        ),
      ),
    );
  }
}
