import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/core/const/app_colors.dart';
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

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.all(0),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withAlpha(30),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(16),
                  topLeft: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ticket Information',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedCancel01,
                      size: 18,
                    ),
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(32, 32),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: getColor(attendeeModel.status).withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        getIcon(attendeeModel.status),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            statusString(attendeeModel.status),
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Column(
                    children: [
                      InfoRow(
                        icon: HugeIcons.strokeRoundedUser,
                        label: "Name",
                        value: attendeeModel.name,
                      ),
                      const SizedBox(height: 20),
                      if (attendeeModel.eventDisplayName.isNotEmpty) ...[
                        InfoRow(
                          icon: HugeIcons.strokeRoundedLicenseThirdParty,
                          label: "Event ",
                          value: attendeeModel.eventDisplayName,
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (attendeeModel.slotName != null &&
                          attendeeModel.slotName!.isNotEmpty) ...[
                        InfoRow(
                          icon: HugeIcons.strokeRoundedCar05,
                          label: "Slot",
                          value: attendeeModel.slotName!,
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (attendeeModel.companyName.isNotEmpty) ...[
                        InfoRow(
                          icon: HugeIcons.strokeRoundedOffice,
                          label: "Company",
                          value: attendeeModel.companyName,
                        ),
                        const SizedBox(height: 20),
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

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          width: double.infinity,
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

                                final file = await services.downloadBadge(
                                  attendeeModel.id,
                                );

                                if (file != null) {
                                  CustomSnackbar.showSuccess(
                                    context,
                                    "Badge downloaded",
                                  );

                                  await OpenFile.open(file.path);
                                } else {
                                  CustomSnackbar.showError(
                                    context,
                                    "Download failed",
                                  );
                                }
                              } catch (e) {
                                CustomSnackbar.showError(
                                  context,
                                  "Error downloading badge",
                                );
                              } finally {
                                hideLoadingDialog(context);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: primaryColor, width: 1),
                              backgroundColor: Colors.white,

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save_outlined, size: 20),
                                SizedBox(width: 10),

                                const Text(
                                  "Download",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditAttendee(
                                    attendeeId: attendeeModel.id,
                                  ),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: primaryColor, width: 1),
                              backgroundColor: Colors.white,

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                HugeIcon(
                                  icon: HugeIcons.strokeRoundedEdit04,
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                const Text(
                                  "Edit",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 15),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          final services = RegistrationServices();
                          await services.actionDone(attendeeModel.id);
                          CustomSnackbar.showSuccess(
                            context,
                            "Registration Confirmed",
                          );
                          final provider = Provider.of<RegistrationProvider>(
                            context,
                            listen: false,
                          );

                          await provider.loadAttendees(reset: true);
                        } catch (e) {
                          CustomSnackbar.showError(
                            context,
                            "Error occurred  while confirm",
                          );
                        }

                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            attendeeModel.status == "need_manual_confirmation"
                                ? "Confirm"
                                : "Continue",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 10),
                          Icon(Icons.arrow_forward),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 15),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
