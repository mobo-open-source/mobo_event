import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/features/event/provider/event_detailed_provider.dart';
import 'package:mobo_event/features/ticket/widget/ticket_card.dart';
import 'package:mobo_event/features/ticket/widget/create_ticket_dailog.dart';
import 'package:mobo_event/shared/widgets/shimmer_card/shimmer_card.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';
import '../../../core/const/app_colors.dart';
import '../../../shared/helper/helper_method.dart';
import '../../../shared/widgets/action_button.dart';
import '../../../shared/widgets/loading/loading_widget.dart';

class TicketLineWidget extends StatelessWidget {
  final int eventId;
  final bool dummyTicket;
  const TicketLineWidget({
    super.key,
    required this.eventId,
    this.dummyTicket = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Ticket Information",
            style: TextStyle(
              fontSize: 18,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: Consumer<EventDetailedProvider>(
              builder: (context, provider, child) {
                return SingleChildScrollView(
                  child: dummyTicket
                      ? _buildDummyTicketContent(provider, context)
                      : _buildContent(provider, context),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDummyTicketContent(
    EventDetailedProvider provider,
    BuildContext context,
  ) {
    if (provider.dummyTicketList.isNotEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListView.builder(
            physics: NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: provider.dummyTicketList.length,
            itemBuilder: (context, index) => TicketCard(
              ticket: provider.dummyTicketList[index],
              eventId: eventId,
              dummy: true,

              onDelete: () async {
                provider.removeDummyTicket(index);
              },
            ),
          ),
          _actionButton(
            label: "Add Ticket",
            icon: HugeIcons.strokeRoundedAdd01,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) =>
                    CreateTicketDialog(eventId: eventId, creation: dummyTicket),
              );
            },
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,

      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,

          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 40),
            const HugeIcon(
              icon: HugeIcons.strokeRoundedTicket01,
              size: 60,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            _actionButton(
              label: "Create Ticket",
              icon: HugeIcons.strokeRoundedAdd01,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => CreateTicketDialog(
                    eventId: eventId,
                    creation: dummyTicket,
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContent(EventDetailedProvider provider, BuildContext context) {
    if (provider.isTicketLoading) {
      return Column(
        children: const [
          FullCardShimmer(height: 100, radius: 5),
          SizedBox(height: 10),
          FullCardShimmer(height: 100, radius: 5),
          SizedBox(height: 10),
          FullCardShimmer(height: 100, radius: 5),
          SizedBox(height: 10),
          FullCardShimmer(height: 100, radius: 5),
        ],
      );
    }

    if (provider.ticketList.isNotEmpty) {
      return Column(
        children: [
          ListView.builder(
            padding: EdgeInsets.zero,
            physics: NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: provider.ticketList.length,
            itemBuilder: (context, index) => TicketCard(
              ticket: provider.ticketList[index],
              eventId: eventId,

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

                  final delete = await provider.deleteTicket(
                    provider.ticketList[index].id!,
                  );
                  if (delete) {
                    await provider.fetchTicket(eventId);

                    hideLoadingDialog(context);
                    CustomSnackbar.showSuccess(
                      context,
                      "Success fully deleted",
                    );
                  } else {
                    CustomSnackbar.showError(context, "Error while deleting");
                    hideLoadingDialog(context);
                  }
                } catch (e) {
                  hideLoadingDialog(context);

                  final error = cleanedError(e.toString());
                  CustomSnackbar.showError(context, "Server Error :$error");
                }
              },
            ),
          ),
          SizedBox(height: 10),

          actionButton(
            label: "Add Ticket",
            icon: HugeIcons.strokeRoundedAdd01,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => CreateTicketDialog(eventId: eventId),
              );
            },
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,

          children: [
            const SizedBox(height: 100),
            const HugeIcon(
              icon: HugeIcons.strokeRoundedTicket01,
              size: 60,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),

            const Text("Add new ticket", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            _actionButton(
              label: "Create Ticket",
              icon: HugeIcons.strokeRoundedAdd01,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => CreateTicketDialog(eventId: eventId),
                );
              },
            ),
          ],
        ),
      ],
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
