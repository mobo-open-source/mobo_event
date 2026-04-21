import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/features/ticket/model/event_ticket_model.dart';
import 'package:mobo_event/features/ticket/model/ticket_prd.dart';
import 'package:mobo_event/features/ticket/services/ticket_services.dart';
import 'package:mobo_event/shared/helper/helper_method.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/loading/loading_widget.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../../event/pages/event_details_screen.dart';
import '../../event/provider/event_detailed_provider.dart';

class CreateTicketDialog extends StatefulWidget {
  final int eventId;
  final bool creation;
  const CreateTicketDialog({
    super.key,
    required this.eventId,
    this.creation = false,
  });

  @override
  State<CreateTicketDialog> createState() => _CreateTicketDialogState();
}

class _CreateTicketDialogState extends State<CreateTicketDialog> {
  final TextEditingController ticketPrdController = TextEditingController();
  final TextEditingController ticketNameController = TextEditingController();
  final TextEditingController ticketPriceController = TextEditingController();
  final TextEditingController saleStartController = TextEditingController();
  final TextEditingController saleEndController = TextEditingController();
  final TextEditingController maximumSeatController = TextEditingController();
  final TextEditingController limitController = TextEditingController();

  DateTime? saleStartDate;
  DateTime? saleEndDate;

  final _service = TicketServices();
  TicketPrdModel? selectedTicketPrdModel;
  FocusNode ticketPrdNode = FocusNode();
  bool get isFormValid {
    final provider = Provider.of<EventDetailedProvider>(context, listen: false);
    return ticketNameController.text.trim().isNotEmpty &&
        (!provider.ticketFields.containsKey('event_ticket_ids') &&
            selectedTicketPrdModel != null);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: primaryColor.withAlpha(20)),
              child: Row(
                children: [
                  const Text(
                    "Create Ticket",
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Consumer<EventDetailedProvider>(
                  builder: (context, provider, child) {
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (provider.ticketFields.containsKey(
                            'product_id',
                          )) ...[
                            const Text(
                              "Ticket Type",
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 5),
                            TypeAheadField<TicketPrdModel>(
                              controller: ticketPrdController,
                              debounceDuration: const Duration(
                                milliseconds: 300,
                              ),
                              emptyBuilder: (context) => Container(
                                width: double.infinity,
                                height: 100,
                                color: Colors.white,
                                padding: const EdgeInsets.all(12),
                                child: Center(
                                  child: const Text("No ticket type found"),
                                ),
                              ),
                              loadingBuilder: (context) => Container(
                                width: double.infinity,
                                height: 100,
                                color: Colors.white,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),

                              suggestionsCallback: (q) async {
                                return await _service.fetchTicketProduct(
                                  search: q,
                                  limit: q.isEmpty ? 5 : 10,
                                );
                              },

                              itemBuilder: (context, s) => Container(
                                color: Colors.white,
                                child: ListTile(title: Text(s.name)),
                              ),

                              onSelected: (value) {
                                setState(() {
                                  selectedTicketPrdModel = value;
                                  ticketPrdController.text = value.name;
                                });
                              },

                              builder: (context, controller, node) {
                                ticketPrdNode = node;
                                return TextField(
                                  controller: controller,
                                  focusNode: node,
                                  decoration: InputDecoration(
                                    hintText: "Select Ticket Type",

                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(5),
                                      borderSide: const BorderSide(
                                        color: Colors.grey,
                                        width: 0.5,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(5),
                                      borderSide: const BorderSide(
                                        color: primaryColor,

                                        width: 1,
                                      ),
                                    ),

                                    hintStyle: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),

                                    suffixIcon: selectedTicketPrdModel != null
                                        ? IconButton(
                                            icon: const Icon(Icons.close),
                                            onPressed: () {
                                              setState(() {
                                                selectedTicketPrdModel = null;
                                                ticketPrdController.clear();
                                              });
                                            },
                                          )
                                        : null,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 15),
                          ],

                          const Text(
                            "Name",
                            style: TextStyle(color: Colors.grey),
                          ),
                          SizedBox(height: 10),
                          TextField(
                            controller: ticketNameController,
                            onChanged: (value) {
                              setState(() {
                                ticketNameController.text = value;
                              });
                            },
                            decoration: InputDecoration(
                              hintText: "please enter name of ticket",
                              hintStyle: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),

                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(5),
                                borderSide: const BorderSide(
                                  color: Colors.grey,
                                  width: 0.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(5),
                                borderSide: const BorderSide(
                                  color: primaryColor,

                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),

                          if (provider.ticketFields.containsKey('price')) ...[
                            const Text(
                              "Price",
                              style: TextStyle(color: Colors.grey),
                            ),
                            SizedBox(height: 10),
                            TextField(
                              keyboardType: TextInputType.number,
                              controller: ticketPriceController,
                              onChanged: (value) {
                                setState(() {
                                  ticketPriceController.text = value;
                                });
                              },
                              decoration: InputDecoration(
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(5),
                                  borderSide: const BorderSide(
                                    color: Colors.grey,
                                    width: 0.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(5),
                                  borderSide: const BorderSide(
                                    color: primaryColor,

                                    width: 1,
                                  ),
                                ),
                                hintText: "please enter the price of ticket",
                                hintStyle: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                          ],
                          const Text(
                            "Sale Start Date",
                            style: TextStyle(color: Colors.grey),
                          ),
                          SizedBox(height: 5),
                          TextField(
                            controller: saleStartController,
                            readOnly: true,
                            onTap: () =>
                                _pickDate(context, saleStartController, true),
                            decoration: InputDecoration(
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(5),
                                borderSide: const BorderSide(
                                  color: Colors.grey,
                                  width: 0.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(5),
                                borderSide: const BorderSide(
                                  color: primaryColor,

                                  width: 1,
                                ),
                              ),
                              hintText: "Select start date",
                              hintStyle: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                              suffixIcon: Padding(
                                padding: const EdgeInsets.all(15),
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedCalendar02,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 15),
                          const Text(
                            "Sale End Date",
                            style: TextStyle(color: Colors.grey),
                          ),
                          SizedBox(height: 5),
                          TextField(
                            controller: saleEndController,
                            readOnly: true,
                            onTap: () =>
                                _pickDate(context, saleEndController, false),
                            decoration: InputDecoration(
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(5),
                                borderSide: const BorderSide(
                                  color: Colors.grey,
                                  width: 0.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(5),
                                borderSide: const BorderSide(
                                  color: primaryColor,

                                  width: 1,
                                ),
                              ),

                              hintText: "Select end date",
                              hintStyle: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                              suffixIcon: Padding(
                                padding: const EdgeInsets.all(15),
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedCalendar02,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),

                          const Text(
                            "Seat",
                            style: TextStyle(color: Colors.grey),
                          ),
                          SizedBox(height: 5),
                          TextField(
                            keyboardType: TextInputType.number,
                            controller: maximumSeatController,
                            onChanged: (value) {
                              setState(() {
                                maximumSeatController.text = value;
                              });
                            },
                            decoration: InputDecoration(
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(5),
                                borderSide: const BorderSide(
                                  color: Colors.grey,
                                  width: 0.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(5),
                                borderSide: const BorderSide(
                                  color: primaryColor,

                                  width: 1,
                                ),
                              ),
                              hintText: "please enter the maximum seat",
                              hintStyle: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),

                          if (provider.ticketFields.containsKey(
                            'limit_max_per_order',
                          )) ...[
                            const SizedBox(height: 15),
                            const Text(
                              "Limit",
                              style: TextStyle(color: Colors.grey),
                            ),
                            SizedBox(height: 5),
                            TextField(
                              keyboardType: TextInputType.number,
                              controller: limitController,
                              onChanged: (value) {
                                setState(() {
                                  limitController.text = value;
                                });
                              },
                              decoration: InputDecoration(
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(5),
                                  borderSide: const BorderSide(
                                    color: Colors.grey,
                                    width: 0.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(5),
                                  borderSide: const BorderSide(
                                    color: primaryColor,

                                    width: 1,
                                  ),
                                ),
                                hintText: "please enter the Limit per order",
                                hintStyle: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 25),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFormValid
                        ? primaryColor
                        : Colors.grey.shade400,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: isFormValid
                      ? () async {
                          try {
                            loadingDialog(
                              context,
                              "Creating ",
                              "Please wait...",
                              LoadingAnimationWidget.fourRotatingDots(
                                color: primaryColor,
                                size: 30,
                              ),
                            );
                            final double? price = double.tryParse(
                              ticketPriceController.text.trim(),
                            );

                            final int? seatsLimit = int.tryParse(
                              limitController.text.trim(),
                            );

                            final int? seatsMax = int.tryParse(
                              maximumSeatController.text.trim(),
                            );

                            if (widget.creation) {
                              final provider =
                                  Provider.of<EventDetailedProvider>(
                                    context,
                                    listen: false,
                                  );

                              final ticket = EventTicket(
                                id: 0,
                                displayName: ticketNameController.text.trim(),
                                name: ticketNameController.text.trim(),
                                seatsLimited: true,
                                seatsMax: seatsMax,
                                productId: selectedTicketPrdModel?.id,
                                productName: selectedTicketPrdModel?.name,
                                price: price ?? 0,
                                priceReduce: 0,
                                startSaleDatetime: saleStartDate,
                                endSaleDatetime: saleEndDate,
                                saleAvailable: true,
                                seatsAvailable: 0,
                                seatsUsed: 0,
                                seatsTaken: 0,
                                limitMaxPerOrder: 0,
                                color: "",
                                priceReduceTaxInc: 0,
                                priceIncl: 0,
                              );

                              provider.addDummyTicket(ticket);

                              hideLoadingDialog(context);
                              Navigator.pop(context);

                              CustomSnackbar.showSuccess(
                                context,
                                "Ticket added",
                              );

                              return;
                            }
                            await _service.createTicket(
                              eventId: widget.eventId,
                              productId: selectedTicketPrdModel?.id,
                              name: ticketNameController.text.trim(),
                              price: price,
                              saleStart: saleStartDate,
                              saleEnd: saleEndDate,
                              seatsLimit: seatsLimit,
                              seatsMax: seatsMax,
                            );
                            hideLoadingDialog(context);

                            CustomSnackbar.showSuccess(
                              context,
                              "Success fully Create",
                            );
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) =>
                                    EventDetailsScreen(id: widget.eventId),
                              ),
                              (route) => route.isFirst,
                            );
                          } catch (e) {
                            hideLoadingDialog(context);
                            Navigator.pop(context);
                            CustomSnackbar.showError(
                              context,
                              cleanedError(e.toString()),
                            );
                          }
                        }
                      : () {},
                  child: const Text("Create"),
                ),
              ),
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    TextEditingController controller,
    bool isStart,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            datePickerTheme: DatePickerThemeData(
              headerBackgroundColor: primaryColor,
              headerForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        controller.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";

        if (isStart) {
          saleStartDate = picked;
        } else {
          saleEndDate = picked;
        }
      });
    }
  }
}
