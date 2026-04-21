import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../../core/const/app_colors.dart';
import '../../../shared/widgets/back_dialog/show_back_dialog.dart';
import '../provider/event_detailed_provider.dart';
import '../widget/create_form.dart';
import '../widget/event_form.dart';

class EventAddScreen extends StatelessWidget {
  const EventAddScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        bool confirm = await showBackDialog(
          context,
          title: 'Go to Home Screen',
          subtitle: "Are you sure go to the home screen?",
          leftButtonName: "Stay",
          rightButtonName: "Leave",
          function: () {
            final provider = Provider.of<EventDetailedProvider>(
              context,
              listen: false,
            );
            provider.clearDummyTicket();
            Navigator.pop(context);
            Navigator.pop(context);
          },
        );
      },

      child: Scaffold(
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
            "Create an event",
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [Expanded(child: CreateForm())],
        ),
      ),
    );
  }
}
