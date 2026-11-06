import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/features/registration/model/demo_question_answer.dart';
import 'package:mobo_event/features/registration/provider/registration_provider.dart';
import 'package:mobo_event/features/registration/services/registration_services.dart';
import 'package:mobo_event/features/registration/widget/question_answer_card.dart';
import 'package:mobo_event/features/registration/widget/question_dailog.dart';
import 'package:mobo_event/shared/helper/helper_method.dart';
import 'package:provider/provider.dart';

import '../../../core/const/app_colors.dart';
import '../../../core/utils/contact_validators.dart';
import '../../../core/utils/odoo_compat.dart';
import '../../../shared/widgets/dialogs/common_dialog.dart';
import '../../../shared/widgets/forms/field_label.dart';
import '../../../shared/widgets/forms/mobo_select_field.dart';
import '../../../shared/widgets/loading/loading_widget.dart';
import '../../../shared/widgets/section_list_state.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../../event/model/fetch_model.dart';
import '../../event/widget/field.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pinned_action_bar.dart';
import '../../../core/utils/screen_layout.dart';

class CreateFormAttendees extends StatefulWidget {
  final bool edit;
  final int byEvent;
  const CreateFormAttendees({super.key, this.edit = false, this.byEvent = 0});

  @override
  State<CreateFormAttendees> createState() => CreateFormAttendeesState();
}

class CreateFormAttendeesState extends State<CreateFormAttendees> {
  final attendeeNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final companyController = TextEditingController();
  final barcodeController = TextEditingController();
  final registrationDateController = TextEditingController();
  final attendedDateController = TextEditingController();

  FetchModel? selectedVisitor;
  FetchModel? selectedEvent;
  FetchModel? selectedTicketType;
  FetchModel? selectedBookedBy;
  FetchModel? selectedCampaign;
  FetchModel? selectedMedium;
  FetchModel? selectedSource;
  FetchModel? selectedSlot;

  bool slot = false;

  /// Edit mode only: what the form held once the attendee loaded. Update
  /// stays disabled until the current values differ from it.
  Map<String, Object?>? _initialValues;
  List<DemoQuestionAnswer> _initialAnswers = const [];

  final services = RegistrationServices();

  @override
  void initState() {
    super.initState();

    if (widget.edit == false) {
      final provider = Provider.of<RegistrationProvider>(
        context,
        listen: false,
      );
      final data = provider.newRegistration;
      if (data == null) {
        _captureInitial(provider);
        return;
      }
      barcodeController.text = data.barcode ?? "";
      selectedDate = DateTime.now();
      attendedDateController.text = _formatDateOnly(selectedDate!);
      if (data.event != null) {
        selectedEvent = FetchModel(
          id: data.event!.id,
          name: data.event!.displayName,
        );
      }
      if (data.isMultiSlots) slot = data.isMultiSlots;
      _captureInitial(provider);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        initialEditing();
      });
    }

    attendeeNameController.addListener(() {
      setState(() {});
    });
    if (widget.edit) {
      // Update compares every field with what was loaded, so typing in any
      // of these has to refresh it too, not just the name.
      for (final c in [emailController, phoneController, companyController]) {
        c.addListener(() => setState(() {}));
      }
    }
  }

  /// Create mode: what the form held once its defaults were filled in.
  void _captureInitial(RegistrationProvider provider) {
    _initialValues = _currentValues();
    _initialAnswers = List.of(provider.demoQuestionAnswer);
  }

  /// True once anything differs from the freshly opened (or loaded) form —
  /// what the screen's back button checks before warning about lost data.
  bool get hasChanges =>
      _hasChanges(Provider.of<RegistrationProvider>(context, listen: false));

  void initialEditing() {
    final provider = Provider.of<RegistrationProvider>(context, listen: false);

    final data = provider.selectedAttendee;
    if (data == null) {
      return;
    }
    attendeeNameController.text = data.name;
    emailController.text = data.email;
    phoneController.text = data.phone;
    companyController.text = data.companyName ?? "";
    if (data.visitorId != null) {
      selectedVisitor = FetchModel(
        id: data.visitorId!.id,
        name: data.visitorId!.displayName,
      );
    }
    if (data.eventId != null) {
      selectedEvent = FetchModel(
        id: data.eventId!.id,
        name: data.eventId!.displayName,
      );
    }
    if (data.eventTicketId != null) {
      selectedTicketType = FetchModel(
        id: data.eventTicketId!.id,
        name: data.eventTicketId!.displayName,
      );
    }
    if (data.partnerId != null) {
      selectedBookedBy = FetchModel(
        id: data.partnerId!.id,
        name: data.partnerId!.displayName,
      );
    }
    if (data.createDate != null) {
      registrationDateController.text =
          "${data.createDate!.day}-${data.createDate!.month}-${data.createDate!.year}";
    }
    if (data.dateClosed != null) {
      attendedDateController.text =
          "${data.dateClosed!.day}-${data.dateClosed!.month}-${data.dateClosed!.year}";
      selectedDate = data.dateClosed;
    }

    if (data.source != null) {
      selectedSource = FetchModel(
        id: data.source!.id,
        name: data.source!.displayName,
      );
    }
    if (data.medium != null) {
      selectedMedium = FetchModel(
        id: data.medium!.id,
        name: data.medium!.displayName,
      );
    }
    if (data.campaign != null) {
      selectedCampaign = FetchModel(
        id: data.campaign!.id,
        name: data.campaign!.displayName,
      );
    }

    if (data.registrationAnswers.isNotEmpty) {
      for (int i = 0; i < data.registrationAnswers.length; i++) {
        final qa = data.registrationAnswers[i];
        provider.saveQuestion(
          DemoQuestionAnswer(
            id: qa.id,
            questionId: qa.question!.id,
            answer: qa.answerText,
            questionName: qa.questionText,
            valueAnswerId: qa.valueAnswerId != null
                ? qa.valueAnswerId[0]
                : false,
            valueTextBox: qa.valueTextBox ?? false,
          ),
        );
      }
    }
    barcodeController.text = data.barcode;

    if (data.isMultiSlots) slot = data.isMultiSlots;
    if (data.eventSlotId != null) {
      selectedSlot = FetchModel(
        id: data.eventSlotId!.id,
        name: data.eventSlotId!.displayName,
      );
    }
    _initialValues = _currentValues();
    _initialAnswers = List.of(provider.demoQuestionAnswer);
    setState(() {});
  }

  @override
  void dispose() {
    attendeeNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    companyController.dispose();
    barcodeController.dispose();
    registrationDateController.dispose();
    attendedDateController.dispose();
    super.dispose();
  }

  DateTime? selectedDate;
  String toOdooDateTime(DateTime dt) {
    final utc = dt.toUtc();
    return "${utc.year.toString().padLeft(4, '0')}-"
        "${utc.month.toString().padLeft(2, '0')}-"
        "${utc.day.toString().padLeft(2, '0')} "
        "${utc.hour.toString().padLeft(2, '0')}:"
        "${utc.minute.toString().padLeft(2, '0')}:"
        "${utc.second.toString().padLeft(2, '0')}";
  }

  Future<void> pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: now,
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

    if (date == null) return;

    setState(() {
      selectedDate = date;
      attendedDateController.text = _formatDateOnly(date);
    });
  }

  String _formatDateOnly(DateTime dt) {
    final local = dt.toLocal();
    return "${local.day}/${local.month}/${local.year}";
  }

  /// Date/time field — same filled recipe as [Field], read-only with a
  /// leading calendar icon (matches the event-create form's date picker).
  Widget _dateField(TextEditingController controller, VoidCallback onTap) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            width: double.infinity,
            // 1px less than the 14×12 inset, to make room for the outline.
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 11),
            decoration: BoxDecoration(
              color: AppTheme.inputFill(isDark),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppTheme.restingBorderColor(isDark)),
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
        );
      },
    );
  }

  bool get isFormValid =>
      attendeeNameController.text.trim().isNotEmpty &&
      selectedEvent != null &&
      (!slot || selectedSlot != null) &&
      ContactValidators.phone(phoneController.text) == null;

  /// Every value Update writes, reduced to something `==` can compare.
  Map<String, Object?> _currentValues() => {
    'name': attendeeNameController.text.trim(),
    'email': emailController.text.trim(),
    'phone': phoneController.text.trim(),
    'company': companyController.text.trim(),
    'visitor': selectedVisitor?.id,
    'event': selectedEvent?.id,
    'slot': selectedSlot?.id,
    'ticket': selectedTicketType?.id,
    'bookedBy': selectedBookedBy?.id,
    'attendedDate': selectedDate,
    'campaign': selectedCampaign?.id,
    'medium': selectedMedium?.id,
    'source': selectedSource?.id,
  };

  /// Answers only ever get added or removed, never edited in place, so
  /// comparing the list element by element (by identity) catches both.
  bool _hasChanges(RegistrationProvider provider) =>
      _initialValues != null &&
      (!mapEquals(_currentValues(), _initialValues) ||
          !listEquals(provider.demoQuestionAnswer, _initialAnswers));

  @override
  Widget build(BuildContext context) {
    // Watched so adding or removing a question answer refreshes the button.
    final registration = context.watch<RegistrationProvider>();
    final canSubmit =
        isFormValid && (!widget.edit || _hasChanges(registration));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final landscape = context.isLandscape;
    // [squeezed]: the footer rides at the end of the scroll instead of below
    // it (see the bottom of this method).
    Widget buildFields(bool squeezed, Widget submit) => SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      // Dragging the form dismisses the keyboard — in landscape it fills most
      // of the window, so this is how the rest of the form is brought back.
      keyboardDismissBehavior: landscape
          ? ScrollViewKeyboardDismissBehavior.onDrag
          : ScrollViewKeyboardDismissBehavior.manual,
      // A phone in landscape is 700–900dp wide: fields stretched across it
      // read badly, so the form is capped and centred (the scroll view itself
      // still spans the screen, keeping its scrollbar at the edge).
      child: ConstrainedContent(
        maxWidth: landscape ? 600 : double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _card("Attendee Information", [
              _label("Attendee Name", isRequired: true),
              Field(
                controller: attendeeNameController,
                hint: "Enter Attendee name",
              ),
              _label("Email"),
              Field(
                controller: emailController,
                hint: "Enter email",
                keyboard: TextInputType.emailAddress,
              ),
              _label("Phone"),
              Field(
                controller: phoneController,
                hint: "Enter Phone number",
                keyboard: TextInputType.phone,
                // Optional, like Odoo's own field — only checked once it's
                // not empty — but what's typed has to read as a number.
                validator: (v) => ContactValidators.phone(v),
                onChanged: (_) => setState(() {}),
              ),
              _label("Visitor"),
              MoboSingleSelectField<FetchModel>(
                selected: selectedVisitor,
                selectedLabel: selectedVisitor?.name,
                hintText: 'Select visitor',
                panelTitle: 'Select Visitor',
                search: (q) async =>
                    (await services.getTypeHeadSearchList(
                          model: "website.visitor",
                          search: q,
                          domain: [],
                          limit: 20,
                        ))
                        .map(
                          (m) =>
                              MoboSelectOption(value: m, label: m.name ?? ''),
                        )
                        .toList(),
                onChanged: (m) => setState(() => selectedVisitor = m),
              ),

              _label("Company"),
              Field(controller: companyController, hint: "Enter Company name"),
            ]),

            _card("Event Information", [
              _label("Event Name", isRequired: true),
              MoboSingleSelectField<FetchModel>(
                selected: selectedEvent,
                selectedLabel: selectedEvent?.name,
                hintText: 'Select event',
                panelTitle: 'Select Event',
                search: (q) async =>
                    (await services.getTypeHeadSearchList(
                          model: "event.event",
                          search: q,
                          domain: [],
                          limit: 20,
                        ))
                        .map(
                          (m) =>
                              MoboSelectOption(value: m, label: m.name ?? ''),
                        )
                        .toList(),
                onChanged: (item) {
                  // Re-picking the event already chosen keeps its slot/ticket.
                  if (item == selectedEvent) return;

                  // A slot and a ticket belong to one event, so changing the
                  // event (or clearing it with the X) resets both.
                  setState(() {
                    selectedEvent = item;
                    selectedSlot = null;
                    selectedTicketType = null;
                    slot = false;
                  });

                  if (item == null) return;

                  Future.microtask(() async {
                    final bool isMultiSlots = await services
                        .onchangeEventChanged(eventId: item.id);

                    // Ignore the answer if the form closed or the event changed
                    // again while it was in flight.
                    if (!mounted || selectedEvent?.id != item.id) return;
                    setState(() {
                      slot = isMultiSlots;
                    });
                  });
                },
              ),

              if (slot) ...[
                _label("Slot", isRequired: true),

                MoboSingleSelectField<FetchModel>(
                  enabled: selectedEvent != null,
                  selected: selectedSlot,
                  selectedLabel: selectedSlot?.name,
                  hintText: 'Select slot',
                  panelTitle: 'Select Slot',
                  search: (q) async =>
                      (await services.getTypeHeadSearchSlotList(
                            model: "event.slot",
                            search: q,
                            domain: [
                              ['event_id', '=', selectedEvent!.id],
                            ],
                            limit: 20,
                          ))
                          .map(
                            (m) =>
                                MoboSelectOption(value: m, label: m.name ?? ''),
                          )
                          .toList(),
                  onChanged: (m) => setState(() => selectedSlot = m),
                ),
              ],

              _label("Barcode"),
              Field(
                controller: barcodeController,
                hint: "Bar code",
                keyboard: TextInputType.number,
                readOnly: true,
              ),
              _label("Booked By"),
              MoboSingleSelectField<FetchModel>(
                selected: selectedBookedBy,
                selectedLabel: selectedBookedBy?.name,
                hintText: 'Select person',
                panelTitle: 'Select Person',
                search: (q) async =>
                    (await services.getTypeHeadSearchList(
                          model: "res.partner",
                          search: q,
                          domain: [],
                          limit: 20,
                        ))
                        .map(
                          (m) =>
                              MoboSelectOption(value: m, label: m.name ?? ''),
                        )
                        .toList(),
                onChanged: (m) => setState(() => selectedBookedBy = m),
              ),

              if (selectedEvent != null) ...[
                _label("Ticket Type"),
                MoboSingleSelectField<FetchModel>(
                  enabled: selectedEvent != null,
                  selected: selectedTicketType,
                  selectedLabel: selectedTicketType?.name,
                  hintText: 'Select ticket type',
                  panelTitle: 'Select Ticket Type',
                  search: (q) async =>
                      (await services.getTypeHeadSearchList(
                            model: "event.event.ticket",
                            search: q,
                            domain: [
                              ['event_id', '=', selectedEvent!.id],
                            ],
                            limit: 20,
                          ))
                          .map(
                            (m) =>
                                MoboSelectOption(value: m, label: m.name ?? ''),
                          )
                          .toList(),
                  onChanged: (m) => setState(() => selectedTicketType = m),
                ),
              ],
              _label("Registration date"),
              Field(
                controller: registrationDateController,
                hint: "Registration date",
                readOnly: true,
              ),
              _label("Attended date"),
              _dateField(attendedDateController, () async {
                await pickDate();
              }),
            ]),

            _card("Marketing Information", [
              _label("Campaign"),
              MoboSingleSelectField<FetchModel>(
                selected: selectedCampaign,
                selectedLabel: selectedCampaign?.name,
                hintText: 'Select campaign',
                panelTitle: 'Select Campaign',
                search: (q) async =>
                    (await services.getTypeHeadSearchList(
                          model: "utm.campaign",
                          search: q,
                          domain: [],
                          limit: 20,
                        ))
                        .map(
                          (m) =>
                              MoboSelectOption(value: m, label: m.name ?? ''),
                        )
                        .toList(),
                onChanged: (m) => setState(() => selectedCampaign = m),
              ),
              _label("Medium"),
              MoboSingleSelectField<FetchModel>(
                selected: selectedMedium,
                selectedLabel: selectedMedium?.name,
                hintText: 'Select medium',
                panelTitle: 'Select Medium',
                search: (q) async =>
                    (await services.getTypeHeadSearchList(
                          model: "utm.medium",
                          search: q,
                          domain: [],
                          limit: 20,
                        ))
                        .map(
                          (m) =>
                              MoboSelectOption(value: m, label: m.name ?? ''),
                        )
                        .toList(),
                onChanged: (m) => setState(() => selectedMedium = m),
              ),
              _label("Source"),
              MoboSingleSelectField<FetchModel>(
                selected: selectedSource,
                selectedLabel: selectedSource?.name,
                hintText: 'Select source',
                panelTitle: 'Select Source',
                search: (q) async =>
                    (await services.getTypeHeadSearchList(
                          model: "utm.source",
                          search: q,
                          domain: [],
                          limit: 20,
                        ))
                        .map(
                          (m) =>
                              MoboSelectOption(value: m, label: m.name ?? ''),
                        )
                        .toList(),
                onChanged: (m) => setState(() => selectedSource = m),
              ),
            ]),

            _questionsCard(),
            if (squeezed)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SizedBox(width: double.infinity, child: submit),
              ),
          ],
        ),
      ),
    );

    final submitButton = ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        disabledBackgroundColor: AppTheme.disabledButtonFillOn(isDark),
        disabledForegroundColor: AppTheme.disabledButtonText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        padding: EdgeInsets.symmetric(vertical: landscape ? 10 : 15),
      ),
      onPressed: canSubmit
          ? () async {
              if (widget.edit == false) {
                try {
                  final compat = await OdooCompat.current();

                  final provider = context.read<RegistrationProvider>();

                  Map<String, dynamic> payload = {
                    'name': attendeeNameController.text.trim(),
                    'state': provider.newRegistration!.state.isNotEmpty
                        ? provider.newRegistration!.state
                        : false,
                    'email': emailController.text.isNotEmpty
                        ? emailController.text
                        : false,
                    'visitor_id': selectedVisitor != null
                        ? selectedVisitor!.id
                        : false,
                    'phone': phoneController.text.isNotEmpty
                        ? phoneController.text
                        : false,
                    'active': provider.newRegistration != null
                        ? provider.newRegistration!.active
                        : false,
                    'company_name': companyController.text.isNotEmpty
                        ? companyController.text
                        : false,

                    'event_id': selectedEvent != null
                        ? selectedEvent!.id
                        : false,
                    if (compat.hasEventSlots)
                      'event_slot_id': selectedSlot != null
                          ? selectedSlot!.id
                          : false,
                    'event_ticket_id': selectedTicketType != null
                        ? selectedTicketType!.id
                        : false,
                    'partner_id': selectedBookedBy != null
                        ? selectedBookedBy!.id
                        : false,
                    'date_closed': selectedDate != null
                        ? toOdooDateTime(selectedDate!)
                        : false,
                    'utm_campaign_id': selectedCampaign != null
                        ? selectedCampaign!.id
                        : false,
                    'utm_medium_id': selectedMedium != null
                        ? selectedMedium!.id
                        : false,
                    'utm_source_id': selectedSource != null
                        ? selectedSource!.id
                        : false,

                    if (provider.demoQuestionAnswer.isNotEmpty)
                      'registration_answer_ids': provider.buildEventQuestion(),
                  };

                  await services.createAttendees(vals: payload);

                  if (widget.byEvent == 0) {
                    await provider.loadAttendees(reset: true);
                  } else {
                    await provider.loadAttendeesByEvent(
                      reset: true,
                      eventId: widget.byEvent,
                    );
                  }
                  CustomSnackbar.showSuccess(
                    context,
                    " Successfully Created Event",
                  );

                  Navigator.pop(context);
                } catch (e) {
                  CustomSnackbar.showError(context, cleanedError(e.toString()));
                }
              } else {
                try {
                  loadingDialog(
                    context,
                    "Updating Attendee",
                    "Please wait while we Updating Attendee",
                    LoadingAnimationWidget.fourRotatingDots(
                      color: primaryColor,
                      size: 30,
                    ),
                  );

                  final compat = await OdooCompat.current();

                  final provider = context.read<RegistrationProvider>();

                  Map<String, dynamic> payload = {
                    'name': attendeeNameController.text.trim(),
                    'email': emailController.text.isNotEmpty
                        ? emailController.text
                        : false,
                    'visitor_id': selectedVisitor != null
                        ? selectedVisitor!.id
                        : false,
                    'phone': phoneController.text.isNotEmpty
                        ? phoneController.text
                        : false,
                    'company_name': companyController.text.isNotEmpty
                        ? companyController.text
                        : false,

                    'event_id': selectedEvent != null
                        ? selectedEvent!.id
                        : false,
                    if (compat.hasEventSlots)
                      'event_slot_id': selectedSlot != null
                          ? selectedSlot!.id
                          : false,

                    'event_ticket_id': selectedTicketType != null
                        ? selectedTicketType!.id
                        : false,
                    'partner_id': selectedBookedBy != null
                        ? selectedBookedBy!.id
                        : false,
                    'date_closed': selectedDate != null
                        ? toOdooDateTime(selectedDate!)
                        : false,
                    'utm_campaign_id': selectedCampaign != null
                        ? selectedCampaign!.id
                        : false,
                    'utm_medium_id': selectedMedium != null
                        ? selectedMedium!.id
                        : false,
                    'utm_source_id': selectedSource != null
                        ? selectedSource!.id
                        : false,

                    'registration_answer_ids': provider
                        .buildEventEditQuestion(),
                  };

                  final success = await services.editAttendee(
                    attendeeId: provider.selectedAttendee!.id,
                    vals: payload,
                  );

                  if (success) {
                    await provider.loadAttendees(reset: true);

                    provider.resetRegistration();
                    hideLoadingDialog(context);

                    Navigator.pop(context, true);

                    CustomSnackbar.showSuccess(
                      context,
                      "Attendee updated successfully",
                    );
                  } else {
                    hideLoadingDialog(context);
                    CustomSnackbar.showError(
                      context,
                      "Failed to update attendee",
                    );
                  }
                } catch (e) {
                  hideLoadingDialog(context);

                  CustomSnackbar.showError(context, cleanedError(e.toString()));
                }
              }
            }
          : null,
      child: Text(
        widget.edit ? "Update Attendee" : "Create Attendee",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );

    // The fields scroll; the submit button stays pinned below them (and above
    // the keyboard when it is open), so it never scrolls out of reach. In
    // landscape the footer tightens (a ~300dp window can't spare portrait's
    // 70dp) and the button is capped to the form's width.
    //
    // With the keyboard up in landscape there can be under ~150dp of body
    // left, and a pinned footer would take most of it (or all of it — a
    // Column can't give the fields a negative height). Below that the button
    // moves to the end of the scroll instead. It sits in the same Column slot
    // either way — the fields are child 0 in both — so a focused text field
    // keeps its focus while the keyboard opens and the footer relocates.
    return LayoutBuilder(
      builder: (context, constraints) {
        final squeezed = constraints.maxHeight < 160;
        return Column(
          children: [
            Expanded(child: buildFields(squeezed, submitButton)),
            if (!squeezed)
              PinnedActionBar(
                padding: landscape
                    ? const EdgeInsets.fromLTRB(20, 6, 20, 8)
                    : const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: ConstrainedContent(
                  maxWidth: landscape ? 600 : double.infinity,
                  child: SizedBox(
                    width: double.infinity,
                    child: submitButton,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// §6 — field label. `isRequired` appends a red bold " *" via [FieldLabel]
  /// instead of baking the asterisk into the string (it needs its own colour).
  Widget _label(String t, {bool isRequired = false}) =>
      FieldLabel(t, isRequired: isRequired, bottomGap: AppTheme.labelGap);

  /// Form-section card — mirrors the event-create form's card: title,
  /// divider, padded children, radius 12, hairline border + card shadow.
  Widget _card(String h, List<Widget> c) => Builder(
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        // 16 between cards, and 16 of padding inside them (see formCardBody):
        // the rhythm of mobo Billing's create-invoice form.
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface(isDark),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppTheme.cardBorder(isDark), width: 0.5),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            formCardHeader(h, isDark),
            formCardBody(c),
          ],
        ),
      );
    },
  );

  /// "Questions" card — same shell as the other form cards, but the header
  /// and empty state reuse [SectionHeader]/[EmptySectionState] (the pattern
  /// the Ticket Information tab uses): a compact "+ Add" pill in the header
  /// once questions exist, and a single full-width "Add Question" tile with
  /// no action button under the list.
  Widget _questionsCard() => Builder(
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Consumer<RegistrationProvider>(
        builder: (context, provider, child) {
          final hasQuestions =
              selectedEvent != null && provider.demoQuestionAnswer.isNotEmpty;

          void openAddDialog() {
            showDialog<String>(
              context: context,
              builder: (_) => QuestionDialog(eventId: selectedEvent!.id),
            );
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.surface(isDark),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppTheme.cardBorder(isDark),
                width: 0.5,
              ),
              boxShadow: AppShadows.card,
            ),
            child: Padding(
              // 10 above the header, not 16: its row is 36 tall to hold the Add
              // pill, so the title sits 6px lower inside it — 10 + 6 puts the
              // title as far from the card's top as in the other cards.
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: "Questions",
                    onAdd: hasQuestions ? openAddDialog : null,
                  ),
                  // The same grey rule as under the other cards' headings, with
                  // the same room above it as the header has below its title.
                  const SizedBox(height: 10),
                  formCardDivider(isDark),
                  const SizedBox(height: 16),
                  if (selectedEvent == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        "Please select your event & add questions",
                        style: TextStyle(
                          color: AppTheme.secondaryLabelColor(isDark),
                        ),
                      ),
                    )
                  else if (provider.demoQuestionAnswer.isEmpty)
                    EmptySectionState(
                      icon: HugeIcons.strokeRoundedHelpCircle,
                      title: "No questions yet",
                      actionLabel: "Add Question",
                      onAction: openAddDialog,
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: provider.demoQuestionAnswer.length,
                      itemBuilder: (context, index) => QuestionAnswerCard(
                        questionAnswer: provider.demoQuestionAnswer[index],
                        onDelete: () async {
                          final qa = provider.demoQuestionAnswer[index];
                          final confirm = await CommonDialog.confirm(
                            context,
                            title: 'Delete Answer',
                            message:
                                'Are you sure you want to delete the answer for "${qa.questionName ?? 'this question'}"?',
                            confirmText: 'Delete',
                          );
                          if (confirm != true) return;
                          provider.deleteQuestion(index);
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
