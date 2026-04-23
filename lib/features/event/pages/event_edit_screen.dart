import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_event/features/event/pages/event_details_screen.dart';
import 'package:mobo_event/features/event/widget/event_form.dart';
import 'package:provider/provider.dart';

import '../../../core/const/app_colors.dart';
import '../../../shared/widgets/back_dialog/show_back_dialog.dart';
import '../provider/event_detailed_provider.dart';

class EventEditScreen extends StatelessWidget {
  const EventEditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        bool confirm = await showBackDialog(
          context,
          title: 'Discard event',
          subtitle:
              "You have unsaved Event data that will be lost if you leave this page.Are you sure you want to discard this Event?",
          leftButtonName: "Stay",
          rightButtonName: "Leave",
          function: () {
            final detailProvider = Provider.of<EventDetailedProvider>(
              context,
              listen: false,
            );

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    EventDetailsScreen(id: detailProvider.eventModel!.id),
              ),
            );
          },
        );
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : backgroundColor,

        appBar: AppBar(
          backgroundColor: isDark ? Colors.grey[900] : backgroundColor,
          leading: GestureDetector(
            onTap: () async {
              bool shouldExit = await showBackDialog(
                context,
                title: 'Discard Event?',
                subtitle:
                    "You have unsaved Event data that will be lost if you leave this page.Are you sure you want to discard this Event?",
                leftButtonName: "Stay",
                rightButtonName: "Leave",
                function: () {
                  Navigator.pop(context, true);
                },
              );
              if (shouldExit) {
                final detailProvider = Provider.of<EventDetailedProvider>(
                  context,
                  listen: false,
                );

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EventDetailsScreen(id: detailProvider.eventModel!.id),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          title: Text(
            "Edit an event",
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [Expanded(child: EventForm())],
        ),
      ),
    );
  }
}
