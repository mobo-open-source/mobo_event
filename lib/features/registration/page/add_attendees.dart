import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/const/app_colors.dart';
import '../../../shared/widgets/back_dialog/show_back_dialog.dart';
import '../widget/create_form_attendees.dart';

class AddAttendees extends StatefulWidget {
  final int eventId;
  const AddAttendees({super.key, required this.eventId});

  @override
  State<AddAttendees> createState() => _AddAttendeesState();
}

class _AddAttendeesState extends State<AddAttendees> {
  final _formKey = GlobalKey<CreateFormAttendeesState>();

  /// Leaves straight away when nothing was entered; otherwise asks first.
  Future<void> _onBack() async {
    if (_formKey.currentState?.hasChanges ?? false) {
      final leave = await showBackDialog(
        context,
        title: 'Discard attendee',
        subtitle:
            "You have unsaved Attendee data that will be lost if you leave this page. Are you sure you want to discard this Attendee?",
        leftButtonName: "Stay",
        rightButtonName: "Leave",
        function: () => Navigator.pop(context, true),
      );
      if (!leave || !mounted) return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onBack();
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : backgroundColor,

        appBar: AppBar(
          leading: GestureDetector(
            onTap: _onBack,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          title: Text(
            "Create Attendee",
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // Left/right only: the form's own footer handles the bottom inset. Zero
        // in portrait; in landscape it keeps the form clear of a notch or the
        // navigation bar.
        body: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CreateFormAttendees(
                  key: _formKey,
                  byEvent: widget.eventId,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
