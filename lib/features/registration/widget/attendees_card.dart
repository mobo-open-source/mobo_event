import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../../../core/services/event_access_rights.dart';
import '../../../core/utils/screen_layout.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../helper/registration_helper.dart';
import '../model/attendee_short_model.dart';
import '../provider/registration_provider.dart';
import '../widget/row_info.dart';
import 'attendee_dailog_box.dart';
import '../../../core/theme/app_theme.dart';

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
    } catch (_) {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final infos = <Widget>[
      if (attendee.companyName != null && attendee.companyName!.isNotEmpty)
        RowInfo(
          icon: HugeIcons.strokeRoundedOffice,
          value: attendee.companyName!,
        ),
      if (attendee.slotName != null)
        RowInfo(
          icon: HugeIcons.strokeRoundedCalendar03,
          value: attendee.slotName!,
        ),
      if (attendee.eventTicketName != null)
        RowInfo(
          icon: HugeIcons.strokeRoundedTicket01,
          value: attendee.eventTicketName!,
        ),
    ];

    // Landscape is short but wide, so the company / slot / ticket lines flow
    // side by side instead of stacking — a card is then ~2 lines instead of ~5
    // and more of them fit on screen.
    final infoSection = <Widget>[
      if (context.isLandscape) ...[
        if (infos.isNotEmpty) ...[
          const SizedBox(height: 5),
          Wrap(
            spacing: 16,
            runSpacing: 3,
            children: [
              for (final info in infos)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: info,
                ),
            ],
          ),
        ],
      ] else ...[
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
            icon: HugeIcons.strokeRoundedCalendar03,
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
    ];

    return Padding(
      // 16, not 20: lines up with a group header's own 16px padding
      // (`_GroupHeader`) when this sits inside a grouped list, so the
      // card's text starts under the header's, not noticeably narrower.
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GestureDetector(
        // Opening an attendee registers them (`register_attendee` marks the
        // registration attended), so it needs write on `event.registration`.
        onTap: context.watch<AccessRights>().canMarkAttended
            ? _handleTap
            : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface(isDark),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [AppShadows.cardShadow],
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
                        color: AppTheme.primaryColor,
                      ),
                    ),

                    if (attendee.eventName != null)
                      Text(
                        attendee.eventName!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey[400]
                              : Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                    ...infoSection,
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
                  : StatusColors.buildStatusBadge(
                      context,
                      getState(attendee.state),
                      color: getStateColor(attendee.state),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
