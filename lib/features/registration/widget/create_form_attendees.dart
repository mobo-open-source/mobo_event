import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/features/registration/model/demo_question_answer.dart';
import 'package:mobo_event/features/registration/provider/registration_provider.dart';
import 'package:mobo_event/features/registration/services/registration_services.dart';
import 'package:mobo_event/features/registration/widget/question_answer_card.dart';
import 'package:mobo_event/features/registration/widget/question_dailog.dart';
import 'package:mobo_event/shared/helper/helper_method.dart';
import 'package:mobo_event/shared/widgets/action_button.dart';
import 'package:provider/provider.dart';

import '../../../core/const/app_colors.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../../shared/widgets/loading/loading_widget.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../../event/model/fetch_model.dart';
import '../../event/widget/field.dart';
import 'type_head.dart';

class CreateFormAttendees extends StatefulWidget {
  final bool edit;
  final int byEvent;
  const CreateFormAttendees({super.key, this.edit = false, this.byEvent = 0});

  @override
  State<CreateFormAttendees> createState() => _CreateFormAttendeesState();
}

class _CreateFormAttendeesState extends State<CreateFormAttendees> {
  final attendeeNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final visitorController = TextEditingController();
  final companyController = TextEditingController();
  final eventController = TextEditingController();
  final barcodeController = TextEditingController();
  final bookedByController = TextEditingController();
  final registrationDateController = TextEditingController();
  final attendedDateController = TextEditingController();
  final ticketTypeController = TextEditingController();
  final slotController = TextEditingController();

  // Marketing controllers
  final campaignController = TextEditingController();
  final mediumController = TextEditingController();
  final sourceController = TextEditingController();
  final suggestionsController = SuggestionsController();

  FetchModel? selectedVisitor;
  FetchModel? selectedEvent;
  FetchModel? selectedTicketType;
  FetchModel? selectedBookedBy;
  FetchModel? selectedCampaign;
  FetchModel? selectedMedium;
  FetchModel? selectedSource;
  FetchModel? selectedSlot;

  bool slot = false;

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
      if (data == null) return;
      barcodeController.text = data.barcode ?? "";
      selectedDate = DateTime.now();
      attendedDateController.text = _formatDateOnly(selectedDate!);
      if (data.event != null) {
        eventController.text = data.event!.displayName;
        selectedEvent = FetchModel(
          id: data.event!.id,
          name: data.event!.displayName,
        );
      }
      if (data.isMultiSlots) slot = data.isMultiSlots;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        initialEditing();
      });
    }

    attendeeNameController.addListener(() {
      setState(() {});
    });
  }

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
      visitorController.text = data.visitorId!.displayName;
      selectedVisitor = FetchModel(
        id: data.visitorId!.id,
        name: data.visitorId!.displayName,
      );
    }
    if (data.eventId != null) {
      eventController.text = data.eventId!.displayName;
      selectedEvent = FetchModel(
        id: data.eventId!.id,
        name: data.eventId!.displayName,
      );
    }
    if (data.eventTicketId != null) {
      ticketTypeController.text = data.eventTicketId!.displayName;
      selectedTicketType = FetchModel(
        id: data.eventTicketId!.id,
        name: data.eventTicketId!.displayName,
      );
    }
    if (data.partnerId != null) {
      bookedByController.text = data.partnerId!.displayName;
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
      sourceController.text = data.source!.displayName;
      selectedSource = FetchModel(
        id: data.source!.id,
        name: data.source!.displayName,
      );
    }
    if (data.medium != null) {
      mediumController.text = data.medium!.displayName;
      selectedMedium = FetchModel(
        id: data.medium!.id,
        name: data.medium!.displayName,
      );
    }
    if (data.campaign != null) {
      campaignController.text = data.campaign!.displayName;
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
      slotController.text = data.eventSlotId!.displayName;
      selectedSlot = FetchModel(
        id: data.eventSlotId!.id,
        name: data.eventSlotId!.displayName,
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    attendeeNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    visitorController.dispose();
    companyController.dispose();
    eventController.dispose();
    barcodeController.dispose();
    bookedByController.dispose();
    registrationDateController.dispose();
    attendedDateController.dispose();
    campaignController.dispose();
    mediumController.dispose();
    sourceController.dispose();
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

  Widget _dateField(TextEditingController controller, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),

          child: Text(controller.text),
        ),
      ),
    );
  }

  bool get isFormValid =>
      attendeeNameController.text.trim().isNotEmpty &&
      selectedEvent != null &&
      (!slot || selectedSlot != null);
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _card("Attendee Information", [
            _label("Attendee Name"),
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
            ),
            _label("Visitor"),
            AppTypeAhead<FetchModel>(
              controller: visitorController,
              hint: "Search Visitor",
              selectedValue: selectedVisitor,
              suggestionsCallback: (value) {
                return services.getTypeHeadSearchList(
                  model: "website.visitor",
                  search: value,
                  domain: [],
                );
              },
              itemLabel: (item) => item.name ?? "",
              onSelected: (item) {
                setState(() {
                  selectedVisitor = item;
                  visitorController.text = item.name ?? "";
                });
              },
              fieldBuilder:
                  (context, controller, focusNode, isSelected, clear) {
                    return Field(
                      controller: controller,
                      focusNode: focusNode,
                      readOnly: isSelected,
                      hint: "Search Visitor",
                      suffixIcon: isSelected
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  visitorController.clear();
                                  selectedVisitor = null;
                                });
                              },
                            )
                          : null,
                    );
                  },
            ),

            _label("Company"),
            Field(controller: companyController, hint: "Enter Company name"),
          ]),

          _card("Event Information", [
            _label("Event Name"),
            AppTypeAhead<FetchModel>(
              controller: eventController,
              hint: "Search Event",
              selectedValue: selectedEvent,
              suggestionsCallback: (value) {
                return services.getTypeHeadSearchList(
                  model: "event.event",
                  search: value,
                  domain: [],
                );
              },
              itemLabel: (item) => item.name ?? "",
              onSelected: (item) {
                setState(() {
                  selectedEvent = item;
                  eventController.text = item.name ?? "";

                  // Reset slot when event changes
                  selectedSlot = null;
                  slotController.clear();
                  slot = false;
                });

                Future.microtask(() async {
                  final bool isMultiSlots = await services.onchangeEventChanged(
                    eventId: item.id,
                  );

                  setState(() {
                    slot = isMultiSlots;
                  });
                });
              },
              fieldBuilder:
                  (context, controller, focusNode, isSelected, clear) {
                    return Field(
                      controller: controller,
                      focusNode: focusNode,
                      readOnly: isSelected,
                      hint: "Search Event",
                      suffixIcon: isSelected
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () async {
                                setState(() {
                                  eventController.clear();
                                  ticketTypeController.clear();
                                  slot = false;
                                  selectedSlot = null;

                                  selectedEvent = null;
                                  selectedTicketType = null;
                                });
                              },
                            )
                          : null,
                    );
                  },
            ),

            if (slot) ...[
              _label(" Slot"),

              AppTypeAhead<FetchModel>(
                controller: slotController,
                hint: "Search slot",
                selectedValue: selectedSlot,
                suggestionsCallback: (value) {
                  return services.getTypeHeadSearchSlotList(
                    model: "event.slot",
                    search: value,
                    domain: [
                      ['event_id', '=', selectedEvent!.id],
                    ],
                  );
                },
                itemLabel: (item) => item.name ?? '',
                onSelected: (item) {
                  setState(() {
                    selectedSlot = item;
                    slotController.text = item.name ?? "";
                  });
                },
                fieldBuilder:
                    (context, controller, focusNode, isSelected, clear) {
                      return Field(
                        hint: "Search slot",
                        controller: controller,
                        focusNode: focusNode,
                        readOnly: isSelected,
                        suffixIcon: isSelected
                            ? IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    slotController.clear();
                                    selectedSlot = null;
                                  });
                                },
                              )
                            : null,
                      );
                    },
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
            AppTypeAhead<FetchModel>(
              controller: bookedByController,
              hint: "Search BookedBy",
              selectedValue: selectedBookedBy,
              suggestionsCallback: (value) {
                return services.getTypeHeadSearchList(
                  model: "res.partner",
                  search: value,
                  domain: [],
                );
              },
              itemLabel: (item) => item.name ?? "",
              onSelected: (item) {
                setState(() {
                  selectedBookedBy = item;
                  bookedByController.text = item.name ?? "";
                });
              },
              fieldBuilder:
                  (context, controller, focusNode, isSelected, clear) {
                    return Field(
                      controller: controller,
                      focusNode: focusNode,
                      readOnly: isSelected,
                      hint: "Search booked by person",
                      suffixIcon: isSelected
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  bookedByController.clear();
                                  selectedBookedBy = null;
                                });
                              },
                            )
                          : null,
                    );
                  },
            ),

            if (selectedEvent != null) ...[
              _label("Ticket Type"),
              AppTypeAhead<FetchModel>(
                controller: ticketTypeController,
                hint: "Search Ticket",
                selectedValue: selectedTicketType,
                suggestionsCallback: (value) {
                  return services.getTypeHeadSearchList(
                    model: "event.event.ticket",
                    search: value,
                    domain: [
                      ['event_id', '=', selectedEvent!.id],
                    ],
                  );
                },
                itemLabel: (item) => item.name ?? "",
                onSelected: (item) {
                  setState(() {
                    selectedTicketType = item;
                    ticketTypeController.text = item.name ?? "";
                  });
                },
                fieldBuilder:
                    (context, controller, focusNode, isSelected, clear) {
                      return Field(
                        controller: controller,
                        focusNode: focusNode,
                        readOnly: isSelected,
                        hint: "Search Ticket",
                        suffixIcon: isSelected
                            ? IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    ticketTypeController.clear();
                                    selectedTicketType = null;
                                  });
                                },
                              )
                            : null,
                      );
                    },
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
            AppTypeAhead<FetchModel>(
              controller: campaignController,
              hint: "Search Campaign",
              selectedValue: selectedCampaign,
              suggestionsCallback: (value) {
                return services.getTypeHeadSearchList(
                  model: "utm.campaign",
                  search: value,
                  domain: [],
                );
              },
              itemLabel: (item) => item.name ?? "",
              onSelected: (item) async {
                setState(() {
                  selectedCampaign = item;
                  campaignController.text = item.name ?? "";
                });
              },
              fieldBuilder:
                  (context, controller, focusNode, isSelected, clear) {
                    return Field(
                      controller: controller,
                      focusNode: focusNode,
                      readOnly: isSelected,
                      hint: "Search Campaign",
                      suffixIcon: isSelected
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  campaignController.clear();
                                  selectedCampaign = null;
                                });
                              },
                            )
                          : null,
                    );
                  },
            ),
            _label("Medium"),
            AppTypeAhead<FetchModel>(
              controller: mediumController,
              hint: "Search Medium",
              selectedValue: selectedMedium,
              suggestionsCallback: (value) {
                return services.getTypeHeadSearchList(
                  model: "utm.medium",
                  search: value,
                  domain: [],
                );
              },
              itemLabel: (item) => item.name ?? "",
              onSelected: (item) {
                setState(() {
                  selectedMedium = item;
                  mediumController.text = item.name ?? "";
                });
              },
              fieldBuilder:
                  (context, controller, focusNode, isSelected, clear) {
                    return Field(
                      controller: controller,
                      focusNode: focusNode,
                      readOnly: isSelected,
                      hint: "Search Medium",
                      suffixIcon: isSelected
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  mediumController.clear();
                                  selectedMedium = null;
                                });
                              },
                            )
                          : null,
                    );
                  },
            ),
            _label("Source"),
            AppTypeAhead<FetchModel>(
              controller: sourceController,
              hint: "Search Source",
              selectedValue: selectedSource,
              suggestionsCallback: (value) {
                return services.getTypeHeadSearchList(
                  model: "utm.source",
                  search: value,
                  domain: [],
                );
              },
              itemLabel: (item) => item.name ?? "",
              onSelected: (item) {
                setState(() {
                  selectedSource = item;
                  sourceController.text = item.name ?? "";
                });
              },
              fieldBuilder:
                  (context, controller, focusNode, isSelected, clear) {
                    return Field(
                      controller: controller,
                      focusNode: focusNode,
                      readOnly: isSelected,
                      hint: "Search Source",
                      suffixIcon: isSelected
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  sourceController.clear();
                                  selectedSource = null;
                                });
                              },
                            )
                          : null,
                    );
                  },
            ),
          ]),

          _card("Questions", [
            if (selectedEvent == null) ...[
              Center(
                child: Column(
                  children: [
                    Text("Please select your event & add questions"),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ] else ...[
              Consumer<RegistrationProvider>(
                builder: (context, provider, child) {
                  if (provider.demoQuestionAnswer.isEmpty) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _actionButton(
                          label: "Add Question",
                          icon: HugeIcons.strokeRoundedAdd01,
                          onPressed: () async {
                            showDialog<String>(
                              context: context,
                              builder: (_) =>
                                  QuestionDialog(eventId: selectedEvent!.id),
                            );
                          },
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        ListView.builder(
                          shrinkWrap: true,
                          itemCount: provider.demoQuestionAnswer.length,
                          physics: NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            return QuestionAnswerCard(
                              questionAnswer:
                                  provider.demoQuestionAnswer[index],
                              onDelete: () {
                                provider.deleteQuestion(index);
                              },
                            );
                          },
                        ),
                        actionButton(
                          label: "Add Question",
                          icon: HugeIcons.strokeRoundedAdd01,
                          onPressed: () async {
                            showDialog<String>(
                              context: context,
                              builder: (_) =>
                                  QuestionDialog(eventId: selectedEvent!.id),
                            );
                          },
                        ),
                      ],
                    );
                  }
                },
              ),
            ],
          ]),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isFormValid
                    ? primaryColor
                    : Colors.grey.shade400,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: isFormValid
                  ? () async {
                      if (widget.edit == false) {
                        try {
                          loadingDialog(
                            context,
                            "Creating Attendee",
                            "Please wait while we Creating Attendee",
                            LoadingAnimationWidget.fourRotatingDots(
                              color: primaryColor,
                              size: 30,
                            ),
                          );
                          final session =
                              await OdooSessionManager.getCurrentSession();

                          final version = session!.odooSession.serverVersion;

                          String odooVersion = version;

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
                            if (odooVersion.contains('19'))
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
                              'registration_answer_ids': provider
                                  .buildEventQuestion(),
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
                          hideLoadingDialog(context);
                          CustomSnackbar.showSuccess(
                            context,
                            " Successfully Created Event",
                          );

                          Navigator.pop(context);
                        } catch (e) {
                          hideLoadingDialog(context);

                          CustomSnackbar.showError(
                            context,
                            cleanedError(e.toString()),
                          );
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

                          final session =
                              await OdooSessionManager.getCurrentSession();

                          final version = session!.odooSession.serverVersion;

                          String odooVersion = version;

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
                            if (odooVersion.contains('19'))
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

                          CustomSnackbar.showError(
                            context,
                            cleanedError(e.toString()),
                          );
                        }
                      }
                    }
                  : () {},
              child: Text(
                widget.edit ? "Update Attendee" : "Create Attendee",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _label(String t) =>
      Text(t, style: const TextStyle(color: Colors.grey));

  Widget _card(String h, List<Widget> c) => Container(
    margin: const EdgeInsets.only(bottom: 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(15),
          child: Text(
            h,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Divider(color: Colors.grey.shade300),
        Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: c
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: e,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    ),
  );

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
