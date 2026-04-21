import 'package:flutter/material.dart';
import 'package:mobo_event/features/event/provider/event_detailed_provider.dart';
import 'package:mobo_event/features/ticket/model/event_ticket_model.dart';
import 'package:mobo_event/features/ticket/widget/edit_ticket_dialog.dart';
import 'package:provider/provider.dart';
import '../../../core/const/app_colors.dart';

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

    return GestureDetector(
      onTap: () {
        if (dummy == false) {
          showDialog(
            context: context,
            builder: (context) =>
                EditTicketDialog(ticket: ticket, eventId: eventId),
          );
        } else {}
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 14, bottom: 14, top: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
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
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      size: 20,
                      color: Colors.grey,
                    ),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onSelected: (value) {
                      if (value == 'delete') onDelete?.call();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: const [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 10),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              if (provider.ticketFields.containsKey('price')) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Text(
                    "₹ ${ticket.price ?? 0}",
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              Row(
                children: [
                  const Icon(
                    Icons.calendar_month,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Sales: ${ticket.startSales} → ${ticket.endSales}",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),

              if (ticket.seatsMax != 0) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.event_seat, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      "Max registrations: ${ticket.seatsMax ?? "no limitation"}",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
