import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/material.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/features/ticket/model/event_ticket_model.dart';
import 'package:mobo_event/features/ticket/model/ticket_prd.dart';
import 'package:mobo_event/features/ticket/services/ticket_services.dart';
import 'package:mobo_event/shared/helper/helper_method.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_layout.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../../../shared/widgets/forms/field_label.dart';
import '../../../shared/widgets/forms/mobo_select_field.dart';
import '../../../shared/widgets/mobo/mobo_button.dart';
import '../../event/pages/event_details_screen.dart';
import '../../event/provider/event_detailed_provider.dart';
import '../../event/widget/field.dart';
import '../helper/ticket_validator.dart';

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

  /// Whether the server would take this ticket — what the Create button gates
  /// on, so it only enables once every visible field passes.
  ///
  /// Ticket Type (and Price) exist only where the server has a product module
  /// (`event_sale` on 17, `event_product` on 18+), and the type is required
  /// there. This used to test a field that isn't on the ticket model at all,
  /// so on a server without a product module — no Ticket Type shown — the
  /// button could never enable.
  bool get isFormValid {
    final fields = Provider.of<EventDetailedProvider>(
      context,
      listen: false,
    ).ticketFields;

    return (!fields.containsKey('product_id') ||
            selectedTicketPrdModel != null) &&
        TicketValidator.isValid(
          name: ticketNameController.text,
          seats: maximumSeatController.text,
          price: ticketPriceController.text,
          limit: limitController.text,
          // The limit per order is Odoo 19+, the price needs a product module.
          hasPrice: fields.containsKey('price'),
          hasLimit: fields.containsKey('limit_max_per_order'),
          saleStart: saleStartDate,
          saleEnd: saleEndDate,
        );
  }

  /// True while the ticket is being sent to the server. The button spins and
  /// the dialog can't be closed meanwhile; nothing opens over the form.
  bool _saving = false;

  Future<void> _create() async {
    if (_saving) return;
    try {
      final double? price = double.tryParse(ticketPriceController.text.trim());
      final int? seatsLimit = int.tryParse(limitController.text.trim());
      final int? seatsMax = int.tryParse(maximumSeatController.text.trim());

      if (widget.creation) {
        // A ticket on an event that isn't saved yet: kept on the form, nothing
        // to wait for.
        final provider = Provider.of<EventDetailedProvider>(
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
          // Was hard-coded to 0, silently dropping what
          // was typed into Limit on Odoo 19.
          limitMaxPerOrder: seatsLimit ?? 0,
          color: "",
          priceReduceTaxInc: 0,
          priceIncl: 0,
        );

        provider.addDummyTicket(ticket);
        Navigator.pop(context);
        CustomSnackbar.showSuccess(context, "Ticket added");
        return;
      }

      setState(() => _saving = true);
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
      if (!mounted) return;
      CustomSnackbar.showSuccess(context, "Success fully Create");
      EventDetailsScreen.openFresh(context, widget.eventId);
    } catch (e) {
      if (!mounted) return;
      // Stay on the form with what was typed, so it can be retried.
      setState(() => _saving = false);
      CustomSnackbar.showError(context, cleanedError(e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final compact = context.isShortScreen;
    return PopScope(
      canPop: !_saving,
      child: Dialog(
        backgroundColor: AppTheme.surface(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: compact
            ? const EdgeInsets.symmetric(horizontal: 40, vertical: 8)
            : null,
        child: LayoutBuilder(
          builder: (context, constraints) =>
              _content(context, constraints.maxHeight),
        ),
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
            "Create Ticket",
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
            onPressed: _saving ? null : () => Navigator.pop(context),
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
      // The button spins while the ticket is created: nothing opens over the
      // dialog, and `isLoading` is what stops a second tap creating it twice.
      child: MoboButton.filled(
        label: "Create",
        onPressed: isFormValid ? _create : null,
        isLoading: _saving,
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
              // The fields' own onChanged only rebuilds so the
              // button re-checks; it must not write the text back
              // into the controller, which resets the cursor.
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
                () => _pickDate(context, saleStartController, true),
              ),

              const SizedBox(height: 15),
              FieldLabel("Sale End Date"),
              const SizedBox(height: 8),
              _dateField(
                saleEndController,
                () => _pickDate(context, saleEndController, false),
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
              const SizedBox(height: 15),

              // Odoo 19 only; older servers have no such field.
              if (provider.ticketFields.containsKey('limit_max_per_order')) ...[
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

  Future<void> _pickDate(
    BuildContext context,
    TextEditingController controller,
    bool isStart,
  ) async {
    // The end can't be picked before the start (Odoo refuses it), so the
    // picker doesn't offer those days.
    final DateTime firstDate = !isStart && saleStartDate != null
        ? saleStartDate!
        : DateTime(2020);
    var initialDate = (isStart ? saleStartDate : saleEndDate) ?? DateTime.now();
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
