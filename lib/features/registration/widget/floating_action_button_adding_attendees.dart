import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/features/registration/page/add_attendees.dart';
import 'package:mobo_event/features/registration/provider/registration_provider.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/loading/loading_widget.dart';

Widget floatingActionButtonAddingAttendees(BuildContext context, int? eventId) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return InkWell(
    onTap: () async {
      try {
        loadingDialog(
          context,
          "Creating new attendee",
          "Please wait while we Fetching details Event",
          LoadingAnimationWidget.fourRotatingDots(
            color: primaryColor,
            size: 30,
          ),
        );

        final provider = Provider.of<RegistrationProvider>(
          context,
          listen: false,
        );

        provider.resetRegistration();

        await provider.onchange(eventId);

        hideLoadingDialog(context);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddAttendees(eventId: eventId ?? 0),
          ),
        );
      } catch (e) {
        hideLoadingDialog(context);

        CustomSnackbar.showError(context, "error ");
      }
    },
    child: Container(
      height: 55,
      width: 55,
      decoration: BoxDecoration(
        color: isDark ? Colors.white : primaryColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedAddTeam,
          color: isDark ? Colors.black : Colors.white,
          strokeWidth: 1,
        ),
      ),
    ),
  );
}
