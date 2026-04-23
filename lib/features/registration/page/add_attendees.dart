import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/const/app_colors.dart';
import '../widget/create_form_attendees.dart';

class AddAttendees extends StatefulWidget {
  final int eventId;
  const AddAttendees({super.key, required this.eventId});

  @override
  State<AddAttendees> createState() => _AddAttendeesState();
}

class _AddAttendeesState extends State<AddAttendees> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : backgroundColor,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: CreateFormAttendees(byEvent: widget.eventId)),
        ],
      ),
    );
  }
}
