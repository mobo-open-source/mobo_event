import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/features/event/pages/event_add_screen.dart';
import 'package:mobo_event/features/event/provider/event_detailed_provider.dart';
import 'package:mobo_event/shared/helper/helper_method.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';

Widget floatingActionButtonAddingEvent(BuildContext context) {
  return InkWell(
    onTap: () async {
      try {
        final provider = Provider.of<EventDetailedProvider>(
          context,
          listen: false,
        );

        await provider.loadFields();

        await provider.createNewSample();
        provider.clearDummyTicket();

        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => EventAddScreen()),
        );
      } catch (e) {
        if (!context.mounted) return;
        CustomSnackbar.showError(context, cleanedError(e.toString()));
      }
    },
    child: Container(
      height: 55,
      width: 55,
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppShadows.cardShadow],
      ),
      child: const Padding(
        padding: EdgeInsets.all(13.0),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedPlusSign,
          color: Colors.white,
          strokeWidth: 2,
        ),
      ),
    ),
  );
}
