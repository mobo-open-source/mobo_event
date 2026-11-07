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
import '../../../core/services/event_access_rights.dart';
import '../../../shared/helper/helper_method.dart';
import '../../../shared/widgets/dialogs/common_dialog.dart';
import '../../../shared/widgets/section_list_state.dart';
import '../../../shared/widgets/loading/loading_widget.dart';

class TicketLineWidget extends StatelessWidget {
  final int eventId;
  final bool dummyTicket;
  const TicketLineWidget({
    super.key,
    required this.eventId,
    this.dummyTicket = false,
  });

  void _addTicket(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) =>
          CreateTicketDialog(eventId: eventId, creation: dummyTicket),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EventDetailedProvider>(
      builder: (context, provider, child) {
        final hasTickets = dummyTicket
            ? provider.dummyTicketList.isNotEmpty
            : !provider.isTicketLoading && provider.ticketList.isNotEmpty;
        // Adding a ticket — staged with a new event or saved straight onto an
        // existing one — is a create on `event.event.ticket`.
        final canAdd = context.watch<AccessRights>().canAddTicket;
        // Nothing to list (and not still loading): the empty state takes the
        // whole area and centres itself, instead of sitting at the top of a
        // scroll view.
        final isEmpty = dummyTicket
            ? provider.dummyTicketList.isEmpty
            : !provider.isTicketLoading && provider.ticketList.isEmpty;
        // The create form leaves the panel unsized while nothing is staged, so
        // the empty state sets its height: there is no bounded area to fill
        // (an Expanded would throw) or to centre it in.
        final hugsEmptyState = dummyTicket && isEmpty;
        return SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SectionHeader(
                title: "Ticket Information",
                onAdd: hasTickets && canAdd ? () => _addTicket(context) : null,
              ),
              const SizedBox(height: 16),
              if (hugsEmptyState)
                _emptyState(context, centered: false)
              else
                Expanded(
                  child: isEmpty
                      ? _emptyState(context)
                      : SingleChildScrollView(
                          child: dummyTicket
                              ? _buildDummyTicketContent(provider, context)
                              : _buildContent(provider, context),
                        ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyState(BuildContext context, {bool centered = true}) {
    final empty = EmptySectionState(
      icon: HugeIcons.strokeRoundedTicket01,
      title: "No tickets yet",
      actionLabel: "Add Ticket",
      compactAction: true,
      onAction: context.watch<AccessRights>().canAddTicket
          ? () => _addTicket(context)
          : null,
    );
    return centered ? CenteredSectionBody(child: empty) : empty;
  }

  Widget _buildDummyTicketContent(
    EventDetailedProvider provider,
    BuildContext context,
  ) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: provider.dummyTicketList.length,
      itemBuilder: (context, index) => TicketCard(
        ticket: provider.dummyTicketList[index],
        eventId: eventId,
        dummy: true,

        onDelete: () async {
          final ticket = provider.dummyTicketList[index];
          final confirm = await CommonDialog.confirm(
            context,
            title: 'Delete Ticket',
            message:
                'Are you sure you want to delete "${ticket.name ?? 'this ticket'}"?',
            confirmText: 'Delete',
          );
          if (confirm != true) return;
          provider.removeDummyTicket(index);
        },
      ),
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

    return ListView.builder(
      padding: EdgeInsets.zero,
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: provider.ticketList.length,
      itemBuilder: (context, index) => TicketCard(
        ticket: provider.ticketList[index],
        eventId: eventId,

        // Deleting a saved ticket is an unlink on `event.event.ticket`; without
        // that right the card has no menu at all.
        onDelete: !context.watch<AccessRights>().canDeleteTicket
            ? null
            : () async {
                final ticket = provider.ticketList[index];
                final confirm = await CommonDialog.confirm(
                  context,
                  title: 'Delete Ticket',
                  message:
                      'Are you sure you want to delete "${ticket.name ?? 'this ticket'}"?',
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
    );
  }
}
