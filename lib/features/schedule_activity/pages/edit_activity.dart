import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/core/theme/app_theme.dart';
import 'package:mobo_event/core/utils/screen_layout.dart';
import 'package:mobo_event/features/schedule_activity/services/event_activity_services.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/forms/field_label.dart';
import '../../../shared/widgets/forms/mobo_select_field.dart';
import '../../../shared/widgets/loading/loading_widget.dart';
import '../../event/widget/field.dart';
import '../../home/providers/home_provider.dart';
import '../model/activity_type.dart';
import '../model/activities_model.dart';
import '../model/user_model.dart';

class EditActivityDialog extends StatefulWidget {
  final ActivitiesModel activiy;

  const EditActivityDialog({super.key, required this.activiy});

  @override
  State<EditActivityDialog> createState() => _EditActivityDialogState();
}

class _EditActivityDialogState extends State<EditActivityDialog> {
  late TextEditingController summaryController;
  late TextEditingController noteController;
  late TextEditingController activityDateController;

  ActivityTypeModel? selectedActivity;
  UserModel? selectedUser;

  final _service = EventActivityServices();

  /// What the dialog held when it opened. Update stays disabled until the
  /// current values differ from it.
  late final Map<String, Object?> _initialValues;

  @override
  void initState() {
    super.initState();

    selectedActivity = ActivityTypeModel(
      id: widget.activiy.activityType[0],
      name: widget.activiy.activityType[1],
    );
    selectedUser = UserModel(
      id: widget.activiy.userId[0],
      name: widget.activiy.userId[1],
    );

    summaryController = TextEditingController(text: widget.activiy.name ?? "");
    noteController = TextEditingController(
      text: stripHtml(widget.activiy.note ?? ""),
    );
    activityDateController = TextEditingController(
      text: widget.activiy.duedate ?? "",
    );

    activityDateController.addListener(() => setState(() {}));
    noteController.addListener(() => setState(() {}));
    _initialValues = _currentValues();
  }

  bool get isFormValid =>
      selectedActivity != null &&
      selectedUser != null &&
      activityDateController.text.isNotEmpty &&
      summaryController.text.trim().isNotEmpty;

  /// Every value Update writes, reduced to something `==` can compare.
  Map<String, Object?> _currentValues() => {
    'activityType': selectedActivity?.id,
    'user': selectedUser?.id,
    'summary': summaryController.text.trim(),
    'date': activityDateController.text,
    'note': noteController.text.trim(),
  };

  bool get canSubmit =>
      isFormValid && !mapEquals(_currentValues(), _initialValues);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // A phone in landscape is only ~300-400dp tall: short windows trim the
    // dialog's outer inset and the title / footer padding so the fields (which
    // scroll) keep as much room as possible, also with the keyboard up.
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
    final compact = context.isShortScreen;
    // Height the dialog really has: the window minus the keyboard and insets.
    // Under 190 even the portrait recipe cannot fit header + footer, and under
    // 124 a pinned footer would leave the fields less than a field's height,
    // so the footer then scrolls with the fields instead of being pinned.
    final dense = compact || avail < 190;
    final tiny = dense && avail < 124;

    final footer = Padding(
      padding: dense
          ? const EdgeInsets.fromLTRB(20, 6, 20, 10)
          : const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: _submitButton(context),
    );

    // The fields scroll; Update stays pinned at the bottom of the dialog.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            keyboardDismissBehavior: dense
                ? ScrollViewKeyboardDismissBehavior.onDrag
                : ScrollViewKeyboardDismissBehavior.manual,
            child: Column(
              children: [
                _header(dense),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _activityField(),
                      const SizedBox(height: 15),
                      _userField(),
                      const SizedBox(height: 15),
                      const FieldLabel("Summary", isRequired: true),
                      const SizedBox(height: 8),
                      Field(
                        controller: summaryController,
                        hint: "eg: Discuss proposal",
                        // Required, so Update re-checks on every keystroke.
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 15),
                      const FieldLabel("Date", isRequired: true),
                      const SizedBox(height: 8),
                      _dateField(context),
                      const SizedBox(height: 15),
                      const FieldLabel("Note"),
                      const SizedBox(height: 8),
                      Field(controller: noteController, hint: "Log note..."),
                    ],
                  ),
                ),
                if (tiny) footer,
              ],
            ),
          ),
        ),
        if (!tiny) footer,
      ],
    );
  }

  Widget _header(bool dense) => Container(
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: dense ? 0 : 10),
    child: Row(
      children: [
        Text(
          "Edit Activity",
          style: TextStyle(
            color: AppTheme.textPrimaryOn(
              Theme.of(context).brightness == Brightness.dark,
            ),
            fontSize: 20,
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

  Widget _activityField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const FieldLabel("Activity Type", isRequired: true),
      const SizedBox(height: 8),
      MoboSingleSelectField<ActivityTypeModel>(
        selected: selectedActivity,
        selectedLabel: selectedActivity?.name,
        hintText: 'Select activity type',
        panelTitle: 'Select Activity Type',
        search: (q) async {
          final types = await _service.fetchActivityTypes(search: q, limit: 20);
          return types
              .map((t) => MoboSelectOption(value: t, label: t.name))
              .toList();
        },
        onChanged: (value) {
          setState(() => selectedActivity = value);
        },
      ),
    ],
  );

  Widget _userField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const FieldLabel("Assigned To", isRequired: true),
      const SizedBox(height: 8),
      MoboSingleSelectField<UserModel>(
        selected: selectedUser,
        selectedLabel: selectedUser?.name,
        hintText: 'Select assignee',
        panelTitle: 'Select Assignee',
        search: (q) async {
          final users = await _service.fetchUsers(search: q, limit: 20);
          return users
              .map((u) => MoboSelectOption(value: u, label: u.name))
              .toList();
        },
        onChanged: (value) {
          setState(() => selectedUser = value);
        },
      ),
    ],
  );

  /// The same filled, calendar-led date field as the app's other forms.
  Widget _dateField(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasDate = activityDateController.text.isNotEmpty;

    return InkWell(
      onTap: () => _pickDate(context),
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
                hasDate ? activityDateController.text : 'Select date',
                style: hasDate
                    ? AppTheme.fieldValueStyle(isDark)
                    : AppTheme.fieldHintStyle(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final d = await showDatePicker(
      context: context,
      initialDate: activityDateController.text.isNotEmpty
          ? DateTime.parse(activityDateController.text)
          : DateTime.now(),
      firstDate: DateTime(2000),
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
    if (d != null) {
      // The controller's listener rebuilds the field and the Update button.
      activityDateController.text =
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    }
  }

  Widget _submitButton(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        disabledBackgroundColor: AppTheme.disabledButtonFillOn(
          Theme.of(context).brightness == Brightness.dark,
        ),
        disabledForegroundColor: AppTheme.disabledButtonText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      onPressed: canSubmit
          ? () async {
              try {
                loadingDialog(
                  context,
                  "Updating Activity",
                  "Please wait...",
                  LoadingAnimationWidget.fourRotatingDots(
                    color: primaryColor,
                    size: 30,
                  ),
                );

                await _service.updateActivity(
                  activityId: widget.activiy.id,
                  typeId: selectedActivity!.id,
                  userId: selectedUser!.id,
                  summary: summaryController.text,
                  note: noteController.text,
                  deadline: activityDateController.text,
                );

                final homeProvider = Provider.of<HomeProvider>(
                  context,
                  listen: false,
                );
                await homeProvider.gettingStages();

                hideLoadingDialog(context);
                Navigator.pop(context);
                Navigator.pop(context);
                CustomSnackbar.showSuccess(
                  context,
                  "Activity updated successfully",
                );
              } catch (_) {
                hideLoadingDialog(context);
                Navigator.pop(context);
                Navigator.pop(context);
                CustomSnackbar.showError(context, "Update failed");
              }
            }
          : null,
      child: const Text("Update"),
    ),
  );

  String stripHtml(String html) {
    final exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false);
    return html.replaceAll(exp, '').trim();
  }
}
