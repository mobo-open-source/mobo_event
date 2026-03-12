import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/features/scheduler/model/template_model.dart';
import 'package:mobo_event/shared/helper/helper_method.dart';
import 'package:provider/provider.dart';
import '../../../core/const/app_colors.dart';
import '../../../shared/widgets/loading/loading_widget.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../../home/providers/home_provider.dart';
import '../model/event_mail_scheduler.dart';
import '../provider/mail_scheduler_provider.dart';
import '../services/mail_scheduler_services.dart' show MailSchedulerServices;

class MailScheduleDialog extends StatefulWidget {
  final int eventId;
  final EventMailScheduler? scheduler;
  final bool isEdit;
  const MailScheduleDialog({
    super.key,
    required this.eventId,
    this.isEdit = false,
    this.scheduler,
  });

  @override
  State<MailScheduleDialog> createState() => _MailScheduleDialogState();
}

class _MailScheduleDialogState extends State<MailScheduleDialog> {
  String selected = 'mail.template';
  String selectedUnit = "now";
  String selectedTrigger = 'after_sub';

  final templateController = TextEditingController();
  final intervalController = TextEditingController();

  TemplateModel? selectedTemplate;
  final _services = MailSchedulerServices();

  FocusNode templateNode = FocusNode();

  bool get isFormValid {
    if (selectedTemplate == null) return false;

    if (selectedUnit != "now") {
      final n = int.tryParse(intervalController.text);
    }

    return true;
  }

  List buildEventSchedulerPayload() {
    return [
      0,
      0,
      {
        "sequence": 1,
        "template_ref": "${selected},${selectedTemplate!.id}",
        "interval_nbr": int.tryParse(intervalController.text) ?? 0,
        "interval_unit": selectedUnit,
        "interval_type": selectedTrigger,
      },
    ];
  }

  @override
  void dispose() {
    templateController.dispose();
    intervalController.dispose();
    templateNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    templateController.addListener(() => setState(() {}));
    if (widget.isEdit) {
      final type = widget.scheduler!.templateRef.toString().split(',')[0];

      if (type.isNotEmpty) selected = type;

      selectedUnit = widget.scheduler!.intervalUnit;
      intervalController.text = widget.scheduler!.intervalNbr.toString();

      selectedTrigger = widget.scheduler!.intervalType;

      templateController.text = widget.scheduler!.templateName!;
      selectedTemplate = TemplateModel(
        id: widget.scheduler!.templateId!,
        name: widget.scheduler!.templateName!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeProvider = Provider.of<HomeProvider>(context, listen: false);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: primaryColor.withAlpha(20),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Text(
                  widget.isEdit
                      ? "Edit Communication"
                      : "Schedule Communication",
                  style: const TextStyle(
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Template Type *",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Flexible(
                      flex: 5,
                      child: SizedBox(
                        height: 48,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: Colors.grey, width: 0.5),
                            color: Colors.white,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              dropdownColor: Colors.white,
                              value: selected,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down),
                              items: const [
                                DropdownMenuItem(
                                  value: 'mail.template',
                                  child: Row(
                                    children: [
                                      Icon(Icons.email_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text('Email'),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'sms.template',
                                  child: Row(
                                    children: [
                                      Icon(Icons.sms_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text('SMS'),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  selected = val!;
                                  templateController.text = '';
                                  selectedTemplate = null;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      flex: 7,
                      child: SizedBox(
                        height: 48,
                        child: TypeAheadField<TemplateModel>(
                          controller: templateController,
                          debounceDuration: const Duration(milliseconds: 300),
                          emptyBuilder: (context) => Container(
                            width: double.infinity,
                            height: 100,
                            color: Colors.white,
                            padding: const EdgeInsets.all(12),
                            child: const Center(
                              child: Text("No template found"),
                            ),
                          ),
                          loadingBuilder: (context) => Container(
                            width: double.infinity,
                            height: 100,
                            color: Colors.white,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          suggestionsCallback: (q) async {
                            return await _services.getTemplate(
                              model: selected,
                              search: q,
                            );
                          },
                          itemBuilder: (context, s) => Container(
                            color: Colors.white,
                            child: ListTile(title: Text(s.name)),
                          ),
                          onSelected: (value) {
                            setState(() {
                              selectedTemplate = value;
                              templateController.text = value.name;
                            });
                            templateNode.unfocus();
                          },
                          builder: (context, controller, node) {
                            return TextField(
                              controller: controller,
                              focusNode: node,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
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
                                hintText: "Select Template",
                                hintStyle: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (selectedTemplate != null)
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 20),
                                        onPressed: () {
                                          setState(() {
                                            selectedTemplate = null;
                                            templateController.clear();
                                          });
                                        },
                                      ),
                                    if (selectedTemplate == null)
                                      const Icon(
                                        Icons.keyboard_arrow_down,
                                        color: Colors.black,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                const Text("Interval*", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 5),

                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: SizedBox(
                        height: 48,
                        child: TextField(
                          enabled: selectedUnit != "now",
                          keyboardType: TextInputType.number,
                          controller: intervalController,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
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
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(5),
                              borderSide: const BorderSide(
                                color: Colors.grey,
                                width: 0.5,
                              ),
                            ),
                            hintText: selectedUnit == "now"
                                ? "Instant"
                                : "Schedule interval",
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      flex: 7,
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.grey, width: 0.5),
                          color: Colors.white,
                        ),
                        child: Center(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedUnit,
                              dropdownColor: Colors.white,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down),
                              items: const [
                                DropdownMenuItem(
                                  value: 'now',
                                  child: Text('Now'),
                                ),
                                DropdownMenuItem(
                                  value: 'hours',
                                  child: Text('Hours'),
                                ),
                                DropdownMenuItem(
                                  value: 'days',
                                  child: Text('Days'),
                                ),
                                DropdownMenuItem(
                                  value: 'weeks',
                                  child: Text('Weeks'),
                                ),
                                DropdownMenuItem(
                                  value: 'months',
                                  child: Text('Months'),
                                ),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  selectedUnit = val!;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),
                const Text("Trigger", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 6),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.grey, width: 0.5),
                    color: Colors.white,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      dropdownColor: Colors.white,
                      value: selectedTrigger,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(
                          value: 'after_sub',
                          child: Text('After each registration'),
                        ),
                        DropdownMenuItem(
                          value: 'before_event',
                          child: Text('Before event starts'),
                        ),
                        if (homeProvider.version.contains('19'))
                          DropdownMenuItem(
                            value: 'after_event_start',
                            child: Text('After event started'),
                          ),
                        DropdownMenuItem(
                          value: 'after_event',
                          child: Text('After event ended'),
                        ),
                        if (homeProvider.version.contains('19'))
                          DropdownMenuItem(
                            value: 'before_event_end',
                            child: Text('Before event ends'),
                          ),
                      ],
                      onChanged: (val) {
                        setState(() {
                          selectedTrigger = val!;
                          if (val == 'after_sub') {
                            selectedUnit = "now";
                            intervalController.clear();
                          }
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 25),

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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: isFormValid
                        ? () async {
                            if (widget.isEdit) {
                              Map<String, dynamic> args = {
                                if (widget.scheduler!.templateId !=
                                    selectedTemplate!.id)
                                  "template_ref":
                                      "${selected},${selectedTemplate!.id}",
                                if (widget.scheduler!.intervalNbr !=
                                    int.tryParse(intervalController.text))
                                  "interval_nbr":
                                      int.tryParse(intervalController.text) ??
                                      0,

                                if (widget.scheduler!.intervalUnit !=
                                    selectedUnit)
                                  "interval_unit": selectedUnit,
                                if (widget.scheduler!.intervalType !=
                                    selectedTrigger)
                                  "interval_type": selectedTrigger,
                              };

                              if (args.isEmpty) {
                                Navigator.pop(context);
                                return;
                              }

                              List<dynamic> payload = [
                                1,
                                widget.scheduler!.id,
                                args,
                              ];

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

                                await _services.attachMailToEvent(
                                  eventId: widget.eventId,
                                  mailValues: payload,
                                );

                                await Provider.of<MailSchedulerProvider>(
                                  context,
                                  listen: false,
                                ).fetchScheduledMail(widget.eventId);
                                CustomSnackbar.showSuccess(
                                  context,
                                  "Success fully Edited",
                                );
                              } catch (e) {
                                CustomSnackbar.showError(
                                  context,
                                  cleanedError(e.toString()),
                                );
                              } finally {
                                hideLoadingDialog(context);
                                Navigator.pop(context);
                              }

                              return;
                            }
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
                              final payload = buildEventSchedulerPayload();

                              await _services.attachMailToEvent(
                                eventId: widget.eventId,
                                mailValues: payload,
                              );
                              hideLoadingDialog(context);

                              await Provider.of<MailSchedulerProvider>(
                                context,
                                listen: false,
                              ).fetchScheduledMail(widget.eventId);
                              CustomSnackbar.showSuccess(
                                context,
                                "Success fully Create",
                              );

                              Navigator.pop(context, true);
                            } catch (e) {
                              hideLoadingDialog(context);
                              Navigator.pop(context, true);
                              CustomSnackbar.showError(
                                context,
                                "Error  while creating ",
                              );
                            }
                          }
                        : () {},
                    child: Text(widget.isEdit ? "Save" : "Create"),
                  ),
                ),
                SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
