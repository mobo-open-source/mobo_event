import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/material.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/core/theme/app_theme.dart';
import 'package:mobo_event/core/utils/screen_layout.dart';
import 'package:mobo_event/features/schedule_activity/services/event_activity_services.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';

import '../../../shared/helper/helper_method.dart';
import '../../../shared/widgets/forms/field_label.dart';
import '../../../shared/widgets/forms/mobo_select_field.dart';
import '../../../shared/widgets/mobo/mobo_button.dart';
import '../../event/widget/field.dart';
import '../../home/providers/home_provider.dart';
import '../model/activity_type.dart';
import '../model/user_model.dart';

class AddActivityDialog extends StatefulWidget {
  final int resId;
  final String model;

  const AddActivityDialog({
    super.key,
    required this.resId,
    required this.model,
  });

  @override
  State<AddActivityDialog> createState() => _AddActivityDialogState();
}

class _AddActivityDialogState extends State<AddActivityDialog> {
  final TextEditingController summaryController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  final TextEditingController activityDateController = TextEditingController();

  ActivityTypeModel? selectedActivity;
  UserModel? selectedUser;

  final _service = EventActivityServices();

  /// True while the activity is being created. The dialog can't be closed
  /// meanwhile, or the pops below would land on the wrong routes.
  bool _creating = false;

  Future<void> _create() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      await _service.createActivity(
        resId: widget.resId,
        model: widget.model,
        typeId: selectedActivity!.id,
        userId: selectedUser!.id,
        summary: summaryController.text,
        note: noteController.text,
        deadline: activityDateController.text,
      );
      if (!mounted) return;
      await Provider.of<HomeProvider>(context, listen: false).gettingStages();
      if (!mounted) return;
      // This dialog and the activity list under it, which is now out of date.
      Navigator.pop(context);
      Navigator.pop(context);
      CustomSnackbar.showSuccess(context, "Success fully created activity");
    } catch (e) {
      if (!mounted) return;
      // Stay on the form with what was typed, so it can be retried.
      setState(() => _creating = false);
      CustomSnackbar.showError(context, cleanedError(e.toString()));
    }
  }

  @override
  void initState() {
    super.initState();
    activityDateController.addListener(() => setState(() {}));
  }

  bool get isFormValid =>
      selectedActivity != null &&
      selectedUser != null &&
      activityDateController.text.isNotEmpty &&
      summaryController.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final compact = context.isShortScreen;
    return PopScope(
      canPop: !_creating,
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
    // A phone in landscape is only ~300-400dp tall: short windows trim the
    // dialog's outer inset and the title / footer padding so the fields (which
    // scroll) keep as much room as possible, also with the keyboard up.
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
      // The button spins while the activity is created: nothing opens over the
      // dialog, and `isLoading` is what stops a second tap creating it twice.
      child: MoboButton.filled(
        label: "Create",
        onPressed: isFormValid ? _create : null,
        isLoading: _creating,
      ),
    );

    // The fields scroll; Create stays pinned at the bottom of the dialog.
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
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: dense ? 0 : 10,
                  ),
                  child: Row(
                    children: [
                      Text(
                        "Create Activity",
                        style: TextStyle(
                          color: AppTheme.textPrimaryOn(isDark),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        visualDensity: dense ? VisualDensity.compact : null,
                        icon: const Icon(Icons.close),
                        onPressed: _creating
                            ? null
                            : () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Column(
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
                          final types = await _service.fetchActivityTypes(
                            search: q,
                            limit: 20,
                          );
                          return types
                              .map(
                                (t) =>
                                    MoboSelectOption(value: t, label: t.name),
                              )
                              .toList();
                        },
                        onChanged: (value) {
                          setState(() => selectedActivity = value);
                        },
                      ),

                      const SizedBox(height: 15),

                      const FieldLabel("Assigned To", isRequired: true),
                      const SizedBox(height: 8),
                      MoboSingleSelectField<UserModel>(
                        selected: selectedUser,
                        selectedLabel: selectedUser?.name,
                        hintText: 'Select assignee',
                        panelTitle: 'Select Assignee',
                        search: (q) async {
                          final users = await _service.fetchUsers(
                            search: q,
                            limit: 20,
                          );
                          return users
                              .map(
                                (u) =>
                                    MoboSelectOption(value: u, label: u.name),
                              )
                              .toList();
                        },
                        onChanged: (value) {
                          setState(() => selectedUser = value);
                        },
                      ),

                      const SizedBox(height: 15),

                      const FieldLabel("Summary", isRequired: true),
                      const SizedBox(height: 8),
                      Field(
                        controller: summaryController,
                        hint: "eg: Discuss proposal",
                        // Required, so Create re-checks on every keystroke.
                        onChanged: (_) => setState(() {}),
                      ),

                      const SizedBox(height: 15),

                      const FieldLabel("Date", isRequired: true),
                      const SizedBox(height: 8),
                      _dateField(context),
                      const SizedBox(height: 15),
                      const FieldLabel("Note"),
                      const SizedBox(height: 8),
                      Field(controller: noteController, hint: "Log notes..."),
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
      initialDate: DateTime.now(),
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
      // The controller's listener rebuilds the field and the Create button.
      activityDateController.text =
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    }
  }
}
