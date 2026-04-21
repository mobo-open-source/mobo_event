import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';

import 'package:provider/provider.dart';
import '../../../core/const/app_colors.dart';
import '../../../shared/widgets/action_button.dart';
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

class _MailSchedulerState extends State<MailScheduler> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<MailSchedulerProvider>().fetchScheduledMail(widget.eventId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 10, right: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Scheduled Information",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: Consumer<MailSchedulerProvider>(
              builder: (context, provider, child) {
                return buildContent(provider, context);
              },
            ),
          ),
        ],
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
                  onDelete: () async {
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

                      await provider.deleteTicket(
                        provider.scheduledMails[index].id,
                      );

                      hideLoadingDialog(context);
                      await provider.fetchScheduledMail(widget.eventId);
                    } catch (e) {
                      hideLoadingDialog(context);

                      CustomSnackbar.showError(context, "Error while deleting");
                    }
                  },
                );
              },
            ),

            actionButton(
              label: "Add Communication",
              icon: HugeIcons.strokeRoundedAdd01,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => MailScheduleDialog(eventId: widget.eventId),
                );
              },
            ),
            SizedBox(height: 30),
          ],
        ),
      );
    }

    if (provider.scheduledMails.isEmpty) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 100),
              const HugeIcon(
                icon: HugeIcons.strokeRoundedBubbleChat,
                size: 60,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text("No Scheduled Information found"),
              const SizedBox(height: 6),
              const SizedBox(height: 16),

              _actionButton(
                label: "Create Communication",
                icon: HugeIcons.strokeRoundedAdd01,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => MailScheduleDialog(eventId: widget.eventId),
                  );
                },
              ),
            ],
          ),
        ],
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

  Widget _actionButton({
    required String label,
    required List<List<dynamic>> icon,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: HugeIcon(icon: icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 12),
      ),
    );
  }
}
