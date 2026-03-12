import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/features/event/pages/event_add_screen.dart';
import 'package:mobo_event/features/event/pages/event_edit_screen.dart';
import 'package:mobo_event/features/event/provider/event_detailed_provider.dart';
import 'package:mobo_event/shared/helper/helper_method.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/loading/loading_widget.dart';
import '../../review/services/review_service.dart';

Widget floatingActionButtonAddingEvent(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return InkWell(
    onTap: () async {
      try {
        loadingDialog(
          context,
          "Creating new Event",
          "Please wait while we Fetching details Event",
          LoadingAnimationWidget.fourRotatingDots(
            color: primaryColor,
            size: 30,
          ),
        );

        final provider = Provider.of<EventDetailedProvider>(
          context,
          listen: false,
        );

        await provider.loadFields();

        await provider.createNewSample();
        provider.clearDummyTicket();

        hideLoadingDialog(context);

        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => EventAddScreen()),
        );
      } catch (e) {
        hideLoadingDialog(context);
        CustomSnackbar.showError(context, cleanedError(e.toString()));
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
          icon: HugeIcons.strokeRoundedPlusSign,
          color: isDark ? Colors.black : Colors.white,
          strokeWidth: 1.5,
        ),
      ),
    ),
  );
}
