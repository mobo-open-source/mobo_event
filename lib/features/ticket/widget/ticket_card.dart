import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/material.dart';
import 'package:mobo_event/features/event/provider/event_detailed_provider.dart';
import 'package:mobo_event/features/ticket/model/event_ticket_model.dart';
import 'package:mobo_event/features/ticket/widget/edit_ticket_dialog.dart';
import 'package:provider/provider.dart';
import '../../../core/services/event_access_rights.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/section_list_state.dart';

class TicketCard extends StatelessWidget {
  final EventTicket ticket;
  final int eventId;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool dummy;

  const TicketCard({
    super.key,
    required this.eventId,
    required this.ticket,
    this.dummy = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<EventDetailedProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // A saved ticket is edited through the event's `event_ticket_ids`, so it
    // opens for editing only when the account can write both models.
    final canEdit = !dummy && context.watch<AccessRights>().canEditTicket;

    // The bordered, shadow-less row the Tickets, Communication and Questions
    // lists share (see [SectionCard]).
    return SectionCard(
      onTap: canEdit
          ? () {
              showDialog(
                context: context,
                builder: (context) =>
                    EditTicketDialog(ticket: ticket, eventId: eventId),
              );
            }
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            // Centred, not top-aligned: the "⋮" sits level with the
            // title text instead of pinned to the top of a taller
            // (two-line) title block.
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (ticket.productName != null) ...[
                      Text(
                        ticket.productName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryOn(isDark),
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      ticket.name ?? "",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.secondaryLabelColor(isDark),
                      ),
                    ),
                  ],
                ),
              ),

              if (onDelete != null) SectionDeleteButton(onPressed: onDelete!),
            ],
          ),

          if (provider.ticketFields.containsKey('price')) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                "${provider.currencySymbol} ${ticket.price ?? 0}",
                style: const TextStyle(
                  color: StatusColors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedCalendar03,
                size: 16,
                color: AppTheme.secondaryLabelColor(isDark),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Sales: ${ticket.startSales} → ${ticket.endSales}",
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.secondaryLabelColor(isDark),
                  ),
                ),
              ),
            ],
          ),

          if (ticket.seatsMax != 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.event_seat,
                  size: 16,
                  color: AppTheme.secondaryLabelColor(isDark),
                ),
                const SizedBox(width: 6),
                Text(
                  "Max registrations: ${ticket.seatsMax ?? "no limitation"}",
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.secondaryLabelColor(isDark),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
