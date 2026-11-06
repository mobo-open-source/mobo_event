import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';

import 'package:provider/provider.dart';
import '../../../core/const/app_colors.dart';
import '../../../core/services/event_access_rights.dart';
import '../../../core/utils/screen_layout.dart';
import '../../../shared/widgets/dialogs/common_dialog.dart';
import '../../../shared/widgets/section_list_state.dart';
import '../../../shared/widgets/loading/loading_widget.dart';
import '../../../shared/widgets/shimmer_card/shimmer_card.dart';
import '../provider/mail_scheduler_provider.dart';
import '../widget/communication_card.dart';
import '../widget/mail_schedule_dialog.dart';

class MailScheduler extends StatefulWidget {
  final int eventId;
  const MailScheduler({super.key, required this.eventId});

  @override
  State<MailScheduler> createState() => _MailSchedulerState();
}

/// Nothing is fetched here: the Details screen loads the scheduled mails
/// together with the rest of the event, and reloads them on refresh.
class _MailSchedulerState extends State<MailScheduler> {
  void _addCommunication() {
    showDialog(
      context: context,
      builder: (_) => MailScheduleDialog(eventId: widget.eventId),
    );
  }

  @override
  Widget build(BuildContext context) {
    // No side padding, same as the Tickets tab's — otherwise its header and
    // cards sit narrower than the Tickets tab's and don't line up with it.
    return Container(
      width: double.infinity,
      child: Consumer<MailSchedulerProvider>(
        builder: (context, provider, child) {
          final hasMails =
              !provider.loading && provider.scheduledMails.isNotEmpty;
          // A scheduler is attached through the event's `event_mail_ids`:
          // adding one needs create on `event.mail` and write on the event.
          final canAdd = context.watch<AccessRights>().canAddScheduler;
          final page = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: "Scheduled Information",
                onAdd: hasMails && canAdd ? _addCommunication : null,
              ),
              const SizedBox(height: 16),
              Expanded(child: buildContent(provider, context)),
            ],
          );
          // One scrolling column; on a wide landscape window it is capped and
          // centred rather than stretched across the whole width.
          return context.isLandscape ? ConstrainedContent(child: page) : page;
        },
      ),
    );
  }

  Widget buildContent(MailSchedulerProvider provider, BuildContext context) {
    if (provider.loading) {
      return SingleChildScrollView(
        child: Column(
          children: const [
            FullCardShimmer(height: 100, radius: 5),
            SizedBox(height: 10),
            FullCardShimmer(height: 100, radius: 5),
            SizedBox(height: 10),
            FullCardShimmer(height: 100, radius: 5),
            SizedBox(height: 10),
            FullCardShimmer(height: 100, radius: 5),
          ],
        ),
      );
    }
    if (provider.scheduledMails.isNotEmpty) {
      return SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: NeverScrollableScrollPhysics(),
              itemCount: provider.scheduledMails.length,
              itemBuilder: (context, index) {
                return MailScheduleCard(
                  eventId: widget.eventId,
                  mail: provider.scheduledMails[index],
                  onDelete: !context.watch<AccessRights>().canDeleteScheduler
                      ? null
                      : () async {
                          final mail = provider.scheduledMails[index];
                          final confirm = await CommonDialog.confirm(
                            context,
                            title: 'Delete Reminder',
                            message:
                                'Are you sure you want to delete "${mail.templateName?.isNotEmpty == true ? mail.templateName : 'this reminder'}"?',
                            confirmText: 'Delete',
                          );
                          if (confirm != true || !context.mounted) return;

                          try {
                            loadingDialog(
                              context,
                              "Deleting ",
                              "Please wait...",
                              LoadingAnimationWidget.fourRotatingDots(
                                color: primaryColor,
                                size: 30,
                              ),
                            );

                            await provider.deleteTicket(mail.id);

                            hideLoadingDialog(context);
                            await provider.fetchScheduledMail(widget.eventId);
                          } catch (e) {
                            hideLoadingDialog(context);

                            CustomSnackbar.showError(
                              context,
                              "Error while deleting",
                            );
                          }
                        },
                );
              },
            ),
          ],
        ),
      );
    }

    if (provider.scheduledMails.isEmpty) {
      return CenteredSectionBody(
        child: EmptySectionState(
          icon: HugeIcons.strokeRoundedBubbleChat,
          title: "No communications yet",
          actionLabel: "Add Communication",
          onAction: context.watch<AccessRights>().canAddScheduler
              ? _addCommunication
              : null,
        ),
      );
    }
    return SingleChildScrollView(
      child: Column(
        children: const [
          FullCardShimmer(height: 100, radius: 5),
          SizedBox(height: 10),
          FullCardShimmer(height: 100, radius: 5),
          SizedBox(height: 10),
          FullCardShimmer(height: 100, radius: 5),
          SizedBox(height: 10),
          FullCardShimmer(height: 100, radius: 5),
        ],
      ),
    );
  }
}
