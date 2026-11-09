import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobo_event/features/scheduler/model/template_model.dart';
import 'package:mobo_event/shared/helper/helper_method.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_layout.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../../home/providers/home_provider.dart';
import '../helper/mail_scheduler_validator.dart';
import '../model/event_mail_scheduler.dart';
import '../provider/mail_scheduler_provider.dart';
import '../services/mail_scheduler_services.dart' show MailSchedulerServices;
import '../../../shared/widgets/forms/field_label.dart';
import '../../../shared/widgets/forms/mobo_select_field.dart';
import '../../../shared/widgets/mobo/mobo_button.dart';
import '../../event/widget/field.dart';

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

  final intervalController = TextEditingController();

  TemplateModel? selectedTemplate;
  final _services = MailSchedulerServices();

  /// The interval to send: an instant ("now") schedule has none, whatever the
  /// field still holds.
  int get _interval => selectedUnit == "now"
      ? 0
      : int.tryParse(intervalController.text.trim()) ?? 0;

  bool get isFormValid {
    if (selectedTemplate == null) return false;

    return MailSchedulerValidator.interval(
          intervalController.text,
          unit: selectedUnit,
        ) ==
        null;
  }

  List buildEventSchedulerPayload() {
    return [
      0,
      0,
      {
        "sequence": 1,
        "template_ref": "${selected},${selectedTemplate!.id}",
        "interval_nbr": _interval,
        "interval_unit": selectedUnit,
        "interval_type": selectedTrigger,
      },
    ];
  }

  /// Edit mode: the scheduler fields that differ from what was loaded —
  /// exactly what Save writes, so the button is enabled only when there is
  /// something to save.
  Map<String, dynamic> _changedArgs() {
    final scheduler = widget.scheduler!;
    final interval = _interval;
    return {
      if (scheduler.templateId != selectedTemplate!.id)
        "template_ref": "$selected,${selectedTemplate!.id}",
      if (scheduler.intervalNbr != interval) "interval_nbr": interval,
      if (scheduler.intervalUnit != selectedUnit) "interval_unit": selectedUnit,
      if (scheduler.intervalType != selectedTrigger)
        "interval_type": selectedTrigger,
    };
  }

  bool get canSubmit =>
      isFormValid && (!widget.isEdit || _changedArgs().isNotEmpty);

  @override
  void dispose() {
    intervalController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Save compares the interval with what was loaded, so typing refreshes it.
    intervalController.addListener(() => setState(() {}));
    if (widget.isEdit) {
      final type = widget.scheduler!.templateRef.toString().split(',')[0];

      if (type.isNotEmpty) selected = type;

      selectedUnit = widget.scheduler!.intervalUnit;
      // An instant schedule has no interval to show.
      if (selectedUnit != "now") {
        intervalController.text = widget.scheduler!.intervalNbr.toString();
      }

      selectedTrigger = widget.scheduler!.intervalType;

      selectedTemplate = TemplateModel(
        id: widget.scheduler!.templateId!,
        name: widget.scheduler!.templateName!,
      );
    }
  }

  /// True while the reminder is being saved. The button spins and the dialog
  /// can't be closed meanwhile; nothing opens over the form.
  bool _saving = false;

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _services.attachMailToEvent(
        eventId: widget.eventId,
        mailValues: widget.isEdit
            ? [1, widget.scheduler!.id, _changedArgs()]
            : buildEventSchedulerPayload(),
      );
    } catch (e) {
      if (!mounted) return;
      // Stay on the form with what was entered, so it can be retried.
      setState(() => _saving = false);
      CustomSnackbar.showError(context, cleanedError(e.toString()));
      return;
    }
    if (!mounted) return;

    // The save went through, so a list that fails to refresh must not read as
    // a failed save — a retry would send the reminder a second time.
    try {
      await Provider.of<MailSchedulerProvider>(
        context,
        listen: false,
      ).fetchScheduledMail(widget.eventId);
    } catch (_) {}
    if (!mounted) return;

    CustomSnackbar.showSuccess(
      context,
      widget.isEdit ? "Success fully Edited" : "Success fully Create",
    );
    Navigator.pop(context, widget.isEdit ? null : true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final compact = context.isShortScreen;
    return PopScope(
      canPop: !_saving,
      child: Dialog(
        insetPadding: compact
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
            : const EdgeInsets.all(16),
        backgroundColor: AppTheme.surface(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: LayoutBuilder(
          builder: (context, constraints) =>
              _content(context, constraints.maxHeight),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, double avail) {
    final homeProvider = Provider.of<HomeProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // A phone in landscape is only ~300-400dp tall, and this dialog used to
    // be one unscrollable column with Create inside it. Fields now scroll and
    // the button is pinned below them; short windows also let the title scroll
    // away with the fields and tighten the footer.
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
            widget.isEdit ? "Edit Communication" : "Schedule Communication",
            style: TextStyle(
              color: AppTheme.textPrimaryOn(isDark),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            visualDensity: dense ? VisualDensity.compact : null,
            icon: Icon(
              Icons.close,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: _saving ? null : () => Navigator.pop(context),
          ),
        ],
      ),
    );

    final fields = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel("Template Type", isRequired: true),
        const SizedBox(height: 5),
        Row(
          children: [
            Flexible(
              flex: 5,
              child: MoboSingleSelectField<String>(
                selected: selected,
                options: const [
                  MoboSelectOption(value: 'mail.template', label: 'Email'),
                  MoboSelectOption(value: 'sms.template', label: 'SMS'),
                ],
                hintText: 'Select template type',
                panelTitle: 'Select Template Type',
                allowClear: false,
                onChanged: (val) {
                  // Re-picking the current type keeps its template.
                  if (val == null || val == selected) return;
                  setState(() {
                    selected = val;
                    // A template belongs to one type, so switching
                    // type drops the one already chosen.
                    selectedTemplate = null;
                  });
                },
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              flex: 7,
              child: MoboSingleSelectField<TemplateModel>(
                selected: selectedTemplate,
                selectedLabel: selectedTemplate?.name,
                hintText: 'Select template',
                panelTitle: 'Select Template',
                search: (q) async {
                  final templates = await _services.getTemplate(
                    model: selected,
                    search: q,
                    limit: 20,
                  );
                  return templates
                      .map((t) => MoboSelectOption(value: t, label: t.name))
                      .toList();
                },
                onChanged: (value) {
                  setState(() => selectedTemplate = value);
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 15),

        const FieldLabel("Interval", isRequired: true),
        const SizedBox(height: 5),

        Row(
          // The interval's error message sits under it, so the unit
          // select must stay at the top rather than re-centre.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Field(
                enabled: selectedUnit != "now",
                keyboard: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                controller: intervalController,
                hint: selectedUnit == "now" ? "Instant" : "Schedule interval",
                validator: (value) =>
                    MailSchedulerValidator.interval(value, unit: selectedUnit),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              flex: 7,
              child: MoboSingleSelectField<String>(
                selected: selectedUnit,
                options: const [
                  MoboSelectOption(value: 'now', label: 'Now'),
                  MoboSelectOption(value: 'hours', label: 'Hours'),
                  MoboSelectOption(value: 'days', label: 'Days'),
                  MoboSelectOption(value: 'weeks', label: 'Weeks'),
                  MoboSelectOption(value: 'months', label: 'Months'),
                ],
                hintText: 'Select unit',
                panelTitle: 'Select Unit',
                allowClear: false,
                onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    selectedUnit = val;
                    // Instant sends have no interval to keep.
                    if (val == "now") intervalController.clear();
                  });
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 15),
        const FieldLabel("Trigger"),
        const SizedBox(height: 6),

        MoboSingleSelectField<String>(
          selected: selectedTrigger,
          options: [
            const MoboSelectOption(
              value: 'after_sub',
              label: 'After each registration',
            ),
            const MoboSelectOption(
              value: 'before_event',
              label: 'Before event starts',
            ),
            if (homeProvider.compat.hasEventBoundaryMailTriggers)
              const MoboSelectOption(
                value: 'after_event_start',
                label: 'After event started',
              ),
            const MoboSelectOption(
              value: 'after_event',
              label: 'After event ended',
            ),
            if (homeProvider.compat.hasEventBoundaryMailTriggers)
              const MoboSelectOption(
                value: 'before_event_end',
                label: 'Before event ends',
              ),
          ],
          hintText: 'Select trigger',
          panelTitle: 'Select Trigger',
          allowClear: false,
          onChanged: (val) {
            if (val == null) return;
            setState(() {
              selectedTrigger = val;
              if (val == 'after_sub') {
                selectedUnit = "now";
                intervalController.clear();
              }
            });
          },
        ),
      ],
    );

    final footer = Padding(
      padding: tiny
          ? const EdgeInsets.fromLTRB(0, 8, 0, 10)
          : dense
          ? const EdgeInsets.fromLTRB(20, 6, 20, 10)
          : const EdgeInsets.fromLTRB(20, 25, 20, 26),
      // The button spins while the reminder is saved: nothing opens over the
      // dialog, and `isLoading` is what stops a second tap sending it twice.
      child: MoboButton.filled(
        label: widget.isEdit ? "Save" : "Create",
        onPressed: canSubmit ? _submit : null,
        isLoading: _saving,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!dense) header,

        Flexible(
          child: SingleChildScrollView(
            keyboardDismissBehavior: dense
                ? ScrollViewKeyboardDismissBehavior.onDrag
                : ScrollViewKeyboardDismissBehavior.manual,
            padding: dense
                ? const EdgeInsets.fromLTRB(20, 0, 20, 8)
                : const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: dense
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [header, fields, if (tiny) footer],
                  )
                : fields,
          ),
        ),

        if (!tiny) footer,
      ],
    );
  }
}
