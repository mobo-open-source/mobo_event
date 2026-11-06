import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/shared/helper/helper_method.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';

import '../../../core/const/app_colors.dart';
import '../../../shared/widgets/loading/loading_widget.dart';
import '../../../shared/widgets/forms/field_label.dart';
import '../../../shared/widgets/forms/mobo_select_field.dart';
import '../../event/pages/event_details_screen.dart';
import '../../event/provider/event_detailed_provider.dart';
import '../../event/widget/field.dart';
import '../helper/ticket_validator.dart';
import '../model/event_ticket_model.dart';
import '../model/ticket_prd.dart';
import '../services/ticket_services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_layout.dart';

class EditTicketDialog extends StatefulWidget {
  final EventTicket ticket;
  final int eventId;

  const EditTicketDialog({
    super.key,
    required this.ticket,
    required this.eventId,
  });

  @override
  State<EditTicketDialog> createState() => _EditTicketDialogState();
}

class _EditTicketDialogState extends State<EditTicketDialog> {
  final TextEditingController ticketNameController = TextEditingController();
  final TextEditingController ticketPriceController = TextEditingController();
  final TextEditingController saleStartController = TextEditingController();
  final TextEditingController saleEndController = TextEditingController();
  final TextEditingController maximumSeatController = TextEditingController();
  final TextEditingController limitController = TextEditingController();
  TicketPrdModel? selectedTicketPrdModel;
  DateTime? saleStartDate;
  DateTime? saleEndDate;

  final _service = TicketServices();
  bool get isFormValid {
    final fields = Provider.of<EventDetailedProvider>(
      context,
      listen: false,
    ).ticketFields;

    // Ticket Type is required wherever the server has the field to show it
    // (a product module: `event_sale` on 17, `event_product` on 18+). The
    // limit per order is Odoo 19+, so it is only checked where it exists.
    return (!fields.containsKey('product_id') ||
            selectedTicketPrdModel != null) &&
        TicketValidator.isValid(
          name: ticketNameController.text,
          seats: maximumSeatController.text,
          price: ticketPriceController.text,
          limit: limitController.text,
          hasPrice: fields.containsKey('price'),
          hasLimit: fields.containsKey('limit_max_per_order'),
          saleStart: saleStartDate,
          saleEnd: saleEndDate,
        );
  }

  /// The ticket fields that differ from what was loaded — exactly what Save
  /// writes, so the button is enabled only when there is something to save.
  Map<String, dynamic> _changedFields(EventDetailedProvider provider) {
    final ticket = widget.ticket;
    final name = ticketNameController.text.trim();
    final double? price = double.tryParse(ticketPriceController.text.trim());
    final int? seatsMax = int.tryParse(maximumSeatController.text.trim());
    final int? seatsLimit = int.tryParse(limitController.text.trim());

    return {
      if (provider.ticketFields.containsKey('product_id') &&
          selectedTicketPrdModel != null &&
          selectedTicketPrdModel!.id != ticket.productId)
        'product_id': selectedTicketPrdModel!.id,
      if (name != (ticket.name ?? '')) 'name': name,
      if (saleStartDate != ticket.startSaleDatetime)
        'start_sale_datetime': saleStartDate != null
            ? formatOdooDateTime(saleStartDate!)
            : false,
      if (saleEndDate != ticket.endSaleDatetime)
        'end_sale_datetime': saleEndDate != null
            ? formatOdooDateTime(saleEndDate!)
            : false,
      if (provider.ticketFields.containsKey('price') && price != ticket.price)
        'price': price,
      // An empty seats/limit box is saved as 0, so it is compared as 0 too.
      if ((seatsMax ?? 0) != (ticket.seatsMax ?? 0)) 'seats_max': seatsMax ?? 0,
      if (provider.ticketFields.containsKey('limit_max_per_order') &&
          (seatsLimit ?? 0) != (ticket.limitMaxPerOrder ?? 0))
        'limit_max_per_order': seatsLimit ?? 0,
    };
  }

  bool get canSubmit =>
      isFormValid &&
      _changedFields(
        Provider.of<EventDetailedProvider>(context, listen: false),
      ).isNotEmpty;

  @override
  void initState() {
    super.initState();
    ticketNameController.text = widget.ticket.name ?? '';
    ticketPriceController.text = widget.ticket.price != null
        ? widget.ticket.price.toString()
        : '';
    saleStartController.text = widget.ticket.startSales;
    saleEndController.text = widget.ticket.endSales;
    saleStartDate = widget.ticket.startSaleDatetime;
    saleEndDate = widget.ticket.endSaleDatetime;
    // Unlimited seats is 0 in Odoo; never the text "null", which the seats
    // check (rightly) rejects.
    maximumSeatController.text = (widget.ticket.seatsMax ?? 0).toString();
    limitController.text = widget.ticket.limitMaxPerOrder != null
        ? widget.ticket.limitMaxPerOrder.toString()
        : '0';
    if (widget.ticket.productId != null || widget.ticket.productName != null)
      selectedTicketPrdModel = TicketPrdModel(
        id: widget.ticket.productId!,
        name: widget.ticket.productName!,
      );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final compact = context.isShortScreen;
    return Dialog(
      backgroundColor: AppTheme.surface(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: compact
          ? const EdgeInsets.symmetric(horizontal: 40, vertical: 8)
          : null,
      child: LayoutBuilder(
        builder: (context, constraints) =>
            _content(context, constraints.maxHeight),
      ),
    );
  }

  Widget _content(BuildContext context, double avail) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // A phone in landscape is only ~300-400dp tall, so the portrait recipe
    // (header + body + footer inside 75% of the height) leaves the body a
    // sliver. Short windows give the dialog the whole height, let the title
    // scroll away with the fields and tighten the pinned footer.
    final compact = context.isShortScreen;
    // Height the dialog really has: the window minus the keyboard and insets.
    // Under 190 even the portrait recipe cannot fit header + footer, and under
    // 124 a pinned footer would leave the fields less than a field's height,
    // so the footer then scrolls with the fields instead of being pinned.
    final dense = compact || avail < 190;
    final tiny = dense && avail < 124;

    final header = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 0 : 20,
        vertical: dense ? 0 : 10,
      ),
      child: Row(
        children: [
          Text(
            "Edit Ticket",
            style: TextStyle(
              color: AppTheme.textPrimaryOn(isDark),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            visualDensity: dense ? VisualDensity.compact : null,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );

    final footer = Padding(
      padding: tiny
          ? const EdgeInsets.fromLTRB(0, 8, 0, 10)
          : dense
          ? const EdgeInsets.fromLTRB(10, 6, 10, 10)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: primaryColor,
            disabledBackgroundColor: AppTheme.disabledButtonFillOn(isDark),
            disabledForegroundColor: AppTheme.disabledButtonText,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: canSubmit
              ? () async {
                  final payload = _changedFields(
                    Provider.of<EventDetailedProvider>(context, listen: false),
                  );

                  try {
                    loadingDialog(
                      context,
                      "Updating Ticket ",
                      "Please wait...",
                      LoadingAnimationWidget.fourRotatingDots(
                        color: primaryColor,
                        size: 30,
                      ),
                    );

                    await _service.editTicket(
                      ticketId: widget.ticket.id!,
                      eventId: widget.eventId,
                      payload: payload,
                    );
                    hideLoadingDialog(context);
                    CustomSnackbar.showSuccess(context, "Success fully Edited");
                    EventDetailsScreen.openFresh(context, widget.eventId);
                  } catch (e) {
                    hideLoadingDialog(context);
                    Navigator.pop(context);

                    CustomSnackbar.showError(
                      context,
                      cleanedError(e.toString()),
                    );
                  }
                }
              : null,
          child: const Text("Save Ticket"),
        ),
      ),
    );

    final form = Consumer<EventDetailedProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          keyboardDismissBehavior: dense
              ? ScrollViewKeyboardDismissBehavior.onDrag
              : ScrollViewKeyboardDismissBehavior.manual,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dense) header,
              if (provider.ticketFields.containsKey('product_id')) ...[
                FieldLabel("Ticket Type", isRequired: true),
                const SizedBox(height: 8),
                MoboSingleSelectField<TicketPrdModel>(
                  selected: selectedTicketPrdModel,
                  selectedLabel: selectedTicketPrdModel?.name,
                  hintText: 'Select ticket type',
                  panelTitle: 'Select Ticket Type',
                  search: (q) async {
                    final List<TicketPrdModel> products = await _service
                        .fetchTicketProduct(search: q, limit: 20);
                    return products
                        .map((p) => MoboSelectOption(value: p, label: p.name))
                        .toList();
                  },
                  onChanged: (value) {
                    setState(() => selectedTicketPrdModel = value);
                  },
                ),
                const SizedBox(height: 15),
              ],

              FieldLabel("Name", isRequired: true),
              const SizedBox(height: 8),
              // onChanged only rebuilds so the button re-checks; it
              // must not write the text back into the controller,
              // which resets the cursor.
              Field(
                controller: ticketNameController,
                hint: "please enter name of ticket",
                validator: TicketValidator.name,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 15),

              if (provider.ticketFields.containsKey('price')) ...[
                FieldLabel("Price"),
                const SizedBox(height: 8),
                Field(
                  controller: ticketPriceController,
                  keyboard: TextInputType.number,
                  hint: "please enter the price of ticket",
                  validator: TicketValidator.price,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 15),
              ],

              FieldLabel("Sale Start Date"),
              const SizedBox(height: 8),
              _dateField(
                saleStartController,
                () => _pickDate(
                  context,
                  saleStartController,
                  true,
                  saleStartDate,
                ),
                onClear: saleStartController.text.isEmpty
                    ? null
                    : () {
                        setState(() {
                          saleStartController.clear();
                          saleStartDate = null;
                        });
                      },
              ),

              const SizedBox(height: 15),
              FieldLabel("Sale End Date"),
              const SizedBox(height: 8),
              _dateField(
                saleEndController,
                () => _pickDate(context, saleEndController, false, saleEndDate),
                onClear: saleEndController.text.isEmpty
                    ? null
                    : () {
                        setState(() {
                          saleEndController.clear();
                          saleEndDate = null;
                        });
                      },
                // Shown here so it also appears when it is the
                // *start* date that was moved past the end.
                error: TicketValidator.saleDates(saleStartDate, saleEndDate),
              ),

              const SizedBox(height: 15),

              FieldLabel("Seat"),
              const SizedBox(height: 8),
              Field(
                controller: maximumSeatController,
                keyboard: TextInputType.number,
                hint: "please enter the maximum seat",
                validator: TicketValidator.seats,
                onChanged: (_) => setState(() {}),
              ),

              // Odoo 19 only; older servers have no such field.
              if (provider.ticketFields.containsKey('limit_max_per_order')) ...[
                const SizedBox(height: 15),
                FieldLabel("Limit"),
                const SizedBox(height: 8),
                Field(
                  controller: limitController,
                  keyboard: TextInputType.number,
                  hint: "please enter the Limit per order",
                  validator: (value) => TicketValidator.limitPerOrder(
                    value,
                    seatsMax: int.tryParse(maximumSeatController.text.trim()),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],

              const SizedBox(height: 25),
              if (tiny) footer,
            ],
          ),
        );
      },
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: dense
            ? double.infinity
            : MediaQuery.of(context).size.height * 0.75,
      ),

      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!dense) header,

          dense
              ? Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: form,
                  ),
                )
              : Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: form,
                  ),
                ),

          if (!tiny) footer,
          if (!dense) const SizedBox(height: 10),
        ],
      ),
    );
  }

  /// §7 date-field recipe — filled container, radius `AppRadius.md`, leading
  /// calendar icon; mirrors `create_form.dart`'s `_dateField` so every
  /// read-only date-picker trigger in the app looks identical.
  ///
  /// [error] gives it the red outline and message a rejected text field gets.
  Widget _dateField(
    TextEditingController controller,
    VoidCallback onTap, {
    VoidCallback? onClear,
    String? error,
  }) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.inputFill(isDark),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  // Always drawn (transparent when fine) so the field doesn't
                  // shift by a pixel when the error appears.
                  border: Border.all(
                    color: error != null
                        ? StatusColors.red
                        : AppTheme.restingBorderColor(isDark),
                  ),
                ),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedCalendar03,
                      size: 20,
                      color: isDark ? Colors.white : Colors.grey[700],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        controller.text,
                        style: AppTheme.fieldValueStyle(isDark),
                      ),
                    ),
                    if (onClear != null)
                      InkWell(
                        onTap: onClear,
                        borderRadius: BorderRadius.circular(12),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 12),
                child: Text(
                  error,
                  style: const TextStyle(color: StatusColors.red, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  String formatOdooDateTime(DateTime dt) {
    final local = dt.toLocal();
    return "${local.year.toString().padLeft(4, '0')}-"
        "${local.month.toString().padLeft(2, '0')}-"
        "${local.day.toString().padLeft(2, '0')} "
        "${local.hour.toString().padLeft(2, '0')}:"
        "${local.minute.toString().padLeft(2, '0')}:"
        "${local.second.toString().padLeft(2, '0')}";
  }

  Future<void> _pickDate(
    BuildContext context,
    TextEditingController controller,
    bool isStart,
    DateTime? initial,
  ) async {
    // The end can't be picked before the start (Odoo refuses it), so the
    // picker doesn't offer those days.
    final DateTime firstDate = !isStart && saleStartDate != null
        ? saleStartDate!
        : DateTime(2020);
    var initialDate = initial ?? DateTime.now();
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2100),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: primaryColor,
                    onPrimary: Colors.white,
                    surface: AppTheme.darkSurface,
                    onSurface: Colors.white,
                  )
                : ColorScheme.light(
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
            "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";

        if (isStart) {
          saleStartDate = picked;
        } else {
          saleEndDate = picked;
        }
      });
    }
  }
}
