import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/core/services/event_access_rights.dart';
import 'package:mobo_event/core/theme/app_theme.dart';
import 'package:mobo_event/core/utils/screen_layout.dart';
import 'package:mobo_event/features/registration/model/attendee_model.dart';
import 'package:mobo_event/features/registration/page/edit_attendee.dart';
import 'package:mobo_event/features/registration/services/registration_services.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/loading/loading_widget.dart';
import '../helper/registration_helper.dart';
import '../provider/registration_provider.dart';
import 'info_row.dart';

class AttendeeDailogBox extends StatelessWidget {
  final AttendeeModel attendeeModel;

  const AttendeeDailogBox({super.key, required this.attendeeModel});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget getIcon(String status) {
      switch (status.toLowerCase()) {
        case 'already_registered':
          return Icon(Icons.warning, color: getColor(attendeeModel.status));
        case 'confirmed_registration':
          return Icon(
            Icons.check_circle,
            color: getColor(attendeeModel.status),
          );
        case 'need_manual_confirmation':
          return Icon(
            Icons.question_mark_sharp,
            color: getColor(attendeeModel.status),
          );
        case 'canceled_registration':
          return Icon(Icons.warning, color: getColor(attendeeModel.status));
        default:
          return Icon(Icons.warning, color: getColor(attendeeModel.status));
      }
    }

    // Editing an attendee is a write on `event.registration`; confirming the
    // registration marks it attended — also a write on `event.registration`.
    final rights = context.watch<AccessRights>();
    final canEdit = rights.canEditAttendee;
    final canConfirm = rights.canMarkAttended;
    final short = context.isShortScreen;

    final header = Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: short ? 8 : 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Ticket Information',
              style: TextStyle(
                color: AppTheme.textPrimaryOn(isDark),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (canEdit)
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditAttendee(attendeeId: attendeeModel.id),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              // The edit icon the other Mobo apps use, in their grey — as on
              // the event forms' image preview.
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedPencilEdit02,
                  size: 18,
                  color: AppTheme.secondaryLabelColor(isDark),
                ),
              ),
            ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(16),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: HugeIcon(icon: HugeIcons.strokeRoundedCancel01, size: 16),
            ),
          ),
        ],
      ),
    );

    final details = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          width: double.infinity,
          decoration: BoxDecoration(
            color: getColor(attendeeModel.status).withAlpha(30),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              IconTheme(
                data: IconThemeData(
                  color: getColor(attendeeModel.status),
                  size: 16,
                ),
                child: getIcon(attendeeModel.status),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  statusString(attendeeModel.status),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        Column(
          children: [
            InfoRow(
              icon: HugeIcons.strokeRoundedUser,
              label: "Name",
              value: attendeeModel.name,
            ),
            const SizedBox(height: 12),
            if (attendeeModel.eventDisplayName.isNotEmpty) ...[
              InfoRow(
                icon: HugeIcons.strokeRoundedLicenseThirdParty,
                label: "Event ",
                value: attendeeModel.eventDisplayName,
              ),
              const SizedBox(height: 12),
            ],
            if (attendeeModel.slotName != null &&
                attendeeModel.slotName!.isNotEmpty) ...[
              InfoRow(
                icon: HugeIcons.strokeRoundedCar05,
                label: "Slot",
                value: attendeeModel.slotName!,
              ),
              const SizedBox(height: 12),
            ],
            if (attendeeModel.companyName.isNotEmpty) ...[
              InfoRow(
                icon: HugeIcons.strokeRoundedOffice,
                label: "Company",
                value: attendeeModel.companyName,
              ),
              const SizedBox(height: 12),
            ],

            if (attendeeModel.ticketName.isNotEmpty) ...[
              InfoRow(
                icon: HugeIcons.strokeRoundedTicket01,
                label: "Ticket",
                value: attendeeModel.ticketName,
              ),
            ],
          ],
        ),
      ],
    );

    final downloadButton = SizedBox(
      height: 46,
      child: OutlinedButton(
        onPressed: () async {
          try {
            final services = RegistrationServices();
            loadingDialog(
              context,
              "Downloading",
              "Please wait while we downloading Attendees card",
              LoadingAnimationWidget.fourRotatingDots(
                color: primaryColor,
                size: 30,
              ),
            );

            final file = await services.downloadBadge(attendeeModel.id);

            if (file != null) {
              CustomSnackbar.showSuccess(context, "Badge downloaded");

              await OpenFile.open(file.path);
            } else {
              CustomSnackbar.showError(context, "Download failed");
            }
          } catch (_) {
            CustomSnackbar.showError(context, "Error downloading badge");
          } finally {
            hideLoadingDialog(context);
          }
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: primaryColor, width: 1),
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.save_outlined, size: 18),
            SizedBox(width: 6),
            Text(
              "Download",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );

    final confirmButton = SizedBox(
      height: 46,
      child: ElevatedButton(
        onPressed: () async {
          try {
            final services = RegistrationServices();
            await services.actionDone(attendeeModel.id);
            CustomSnackbar.showSuccess(context, "Registration Confirmed");
            final provider = Provider.of<RegistrationProvider>(
              context,
              listen: false,
            );

            await provider.loadAttendees(reset: true);
          } catch (_) {
            CustomSnackbar.showError(context, "Error occurred  while confirm");
          }

          Navigator.pop(context);
        },
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              attendeeModel.status == "need_manual_confirmation"
                  ? "Confirm"
                  : "Continue",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward, size: 18),
          ],
        ),
      ),
    );

    // Header and the button footer stay pinned and only the details scroll,
    // so on a short (landscape) window the buttons are never scrolled out of
    // reach. Paddings tighten there to leave the details more of the height.
    // If something (the keyboard, left up from a search) leaves under ~240dp,
    // even that is too much — a Column can't give the details a negative
    // height — so the header and buttons ride in the scroll instead.
    // (Read from MediaQuery rather than a LayoutBuilder: AlertDialog measures
    // its content's intrinsic width, which a LayoutBuilder can't answer.)
    final squeezed =
        short &&
        MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom <
            240;
    final actions = Row(
      children: [
        Expanded(child: downloadButton),
        if (canConfirm) ...[
          const SizedBox(width: 10),
          Expanded(child: confirmButton),
        ],
      ],
    );

    return AlertDialog(
      backgroundColor: AppTheme.surface(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.all(0),
      insetPadding: short
          ? const EdgeInsets.symmetric(horizontal: 40, vertical: 12)
          : null,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!squeezed) header,
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                short && !squeezed ? 4 : 16,
                16,
                squeezed ? 12 : 0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (squeezed) header,
                  details,
                  if (squeezed) ...[const SizedBox(height: 10), actions],
                ],
              ),
            ),
          ),
          if (!squeezed)
            Padding(
              padding: short
                  ? const EdgeInsets.fromLTRB(16, 10, 16, 12)
                  : const EdgeInsets.all(16),
              child: actions,
            ),
        ],
      ),
    );
  }
}
