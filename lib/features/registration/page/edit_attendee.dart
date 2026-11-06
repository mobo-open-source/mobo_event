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
  final _formKey = GlobalKey<CreateFormAttendeesState>();

  /// Leaves straight away when nothing was edited; otherwise asks first.
  Future<void> _onBack() async {
    final provider = Provider.of<RegistrationProvider>(context, listen: false);
    if (_formKey.currentState?.hasChanges ?? false) {
      final leave = await showBackDialog(
        context,
        title: 'Discard changes',
        subtitle:
            "You have unsaved Attendee data that will be lost if you leave this page. Are you sure you want to discard these changes?",
        leftButtonName: "Stay",
        rightButtonName: "Leave",
        function: () => Navigator.pop(context, true),
      );
      if (!leave || !mounted) return;
    }
    provider.resetRegistration();
    Navigator.pop(context);
  }

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
    } catch (_) {
      CustomSnackbar.showError(context, "error fetching attendee details");
    }
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
            "Edit Attendee",
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        backgroundColor: isDark ? Colors.grey[900] : backgroundColor,

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
                      return CreateFormAttendees(key: _formKey, edit: true);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
