import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';

import '../../../core/const/app_colors.dart';
import '../../../shared/widgets/back_dialog/show_back_dialog.dart';
import '../../../shared/widgets/shimmer_card/shimmer_card.dart';
import '../provider/registration_provider.dart';
import '../widget/create_form_attendees.dart';

class EditAttendee extends StatefulWidget {
  final int attendeeId;
  const EditAttendee({super.key, required this.attendeeId});

  @override
  State<EditAttendee> createState() => _EditAttendeeState();
}

class _EditAttendeeState extends State<EditAttendee> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initialLoading(widget.attendeeId);
    });
  }

  Future initialLoading(int id) async {
    try {
      final provider = Provider.of<RegistrationProvider>(
        context,
        listen: false,
      );

      await provider.getSelectedAttendeeInformation(id);
    } catch (e) {
      CustomSnackbar.showError(context, "error fetching attendee details");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        bool confirm = await showBackDialog(
          context,
          title: 'Go to Attendees list page',
          subtitle: "Are you sure go to the Attendees list page?",
          leftButtonName: "Stay",
          rightButtonName: "Leave",
          function: () {
            final provider = Provider.of<RegistrationProvider>(
              context,
              listen: false,
            );
            provider.resetRegistration();
            Navigator.pop(context);
            Navigator.pop(context);
          },
        );
      },

      child: Scaffold(
        appBar: AppBar(
          backgroundColor: isDark ? Colors.grey[900] : backgroundColor,
          leading: GestureDetector(
            onTap: () async {
              bool confirm = await showBackDialog(
                context,
                title: 'Go to Attendees list page',
                subtitle: "Are you sure go to the Attendees list page?",
                leftButtonName: "Stay",
                rightButtonName: "Leave",
                function: () {
                  final provider = Provider.of<RegistrationProvider>(
                    context,
                    listen: false,
                  );
                  provider.resetRegistration();
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
              );
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
            "Edit Attendee",
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Expanded(
              child: Consumer<RegistrationProvider>(
                builder: (context, provider, child) {
                  if (provider.editLoading) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ListView(
                        children: const [
                          FullCardShimmer(height: 150),
                          FullCardShimmer(height: 150),
                          FullCardShimmer(height: 150),
                          FullCardShimmer(height: 150),
                          FullCardShimmer(height: 150),
                          FullCardShimmer(height: 150),
                        ],
                      ),
                    );
                  } else if (provider.selectedAttendee == null) {
                    return Text("data not found");
                  } else {
                    return CreateFormAttendees(edit: true);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
