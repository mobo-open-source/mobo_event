import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../helper/registration_helper.dart';
import '../model/attendee_short_model.dart';
import '../provider/registration_provider.dart';
import '../widget/row_info.dart';
import 'attendee_dailog_box.dart';

class AttendeesCard extends StatefulWidget {
  final int id;
  final AttendeeShortModel attendeeShortModel;

  const AttendeesCard({
    super.key,
    required this.attendeeShortModel,
    this.id = 0,
  });

  @override
  State<AttendeesCard> createState() => _AttendeesCardState();
}

class _AttendeesCardState extends State<AttendeesCard> {
  bool isLoading = false;

  Future<void> _handleTap() async {
    final provider = Provider.of<RegistrationProvider>(context, listen: false);

    if (isLoading) return;

    setState(() => isLoading = true);

    try {
      await provider.scanQr(widget.attendeeShortModel.barcode);

      if (!mounted) return;

      if (provider.scannedAttendee != null) {
        showDialog(
          context: context,
          builder: (dialogContext) {
            return AttendeeDailogBox(attendeeModel: provider.scannedAttendee!);
          },
        );
      } else {
        CustomSnackbar.showError(
          context,
          "Something went wrong. Please check your system.",
        );
      }
    } catch (e) {
      if (!mounted) return;

      CustomSnackbar.showError(
        context,
        "Something went wrong. Please check your system.",
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
      if (widget.id == 0) {
        provider.loadAttendees(reset: true);
      } else {
        provider.loadAttendeesByEvent(eventId: widget.id, reset: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendee = widget.attendeeShortModel;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attendee.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    if (attendee.eventName != null)
                      Text(
                        attendee.eventName!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                    if (attendee.companyName != null &&
                        attendee.companyName!.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      RowInfo(
                        icon: HugeIcons.strokeRoundedOffice,
                        value: attendee.companyName!,
                      ),
                    ],

                    if (attendee.slotName != null) ...[
                      const SizedBox(height: 3),
                      RowInfo(
                        icon: HugeIcons.strokeRoundedCalendar02,
                        value: attendee.slotName!,
                      ),
                    ],

                    if (attendee.eventTicketName != null) ...[
                      const SizedBox(height: 3),
                      RowInfo(
                        icon: HugeIcons.strokeRoundedTicket01,
                        value: attendee.eventTicketName!,
                      ),
                    ],
                  ],
                ),
              ),

              isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : attendee.state.isEmpty
                  ? SizedBox.shrink()
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: getStateColor(attendee.state).withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        getState(attendee.state),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: getStateColor(attendee.state),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
