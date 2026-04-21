import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/features/schedule_activity/services/event_activity_services.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/loading/loading_widget.dart';
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
  late TextEditingController activitySearchController;
  late TextEditingController assigneesSearchController;

  ActivityTypeModel? selectedActivity;
  UserModel? selectedUser;

  final _service = EventActivityServices();

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
    activitySearchController = TextEditingController(
      text: widget.activiy.activityType[1],
    );
    assigneesSearchController = TextEditingController(
      text: widget.activiy.userId[1],
    );

    activityDateController.addListener(() => setState(() {}));
  }

  bool get isFormValid =>
      selectedActivity != null &&
      selectedUser != null &&
      activityDateController.text.isNotEmpty &&
      summaryController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _header(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _activityField(),
                  const SizedBox(height: 15),
                  _userField(),
                  const SizedBox(height: 15),
                  const Text("Summary", style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 5),
                  TextField(
                    controller: summaryController,
                    onChanged: (value) {
                      setState(() {
                        summaryController.text = value;
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
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text("Date", style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 5),
                  _dateField(context),
                  const SizedBox(height: 15),
                  const Text("Note", style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 5),
                  TextField(
                    controller: noteController,
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
                      hintText: "Log note....",
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 25),
                  _submitButton(context),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    decoration: BoxDecoration(color: primaryColor.withAlpha(20)),
    child: Row(
      children: [
        const Text(
          "Edit Activity",
          style: TextStyle(
            color: primaryColor,
            fontSize: 20,
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
  );

  Widget _activityField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text("Activity Type", style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 5),
      TypeAheadField<ActivityTypeModel>(
        controller: activitySearchController,

        suggestionsCallback: (q) async =>
            _service.fetchActivityTypes(search: q, limit: q.isEmpty ? 3 : 10),
        itemBuilder: (_, s) => Container(
          color: Colors.white,
          child: ListTile(title: Text(s.name)),
        ),
        onSelected: (value) {
          setState(() {
            selectedActivity = value;
            activitySearchController.text = value.name;
          });
        },
        builder: (_, controller, node) => TextField(
          controller: controller,
          focusNode: node,
          decoration: InputDecoration(
            hintText: "Select Activity",
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: Colors.grey, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: primaryColor, width: 1),
            ),
            suffixIcon: selectedActivity != null
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        selectedActivity = null;
                        activitySearchController.clear();
                      });
                    },
                  )
                : null,
          ),
        ),
      ),
    ],
  );

  Widget _userField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text("Assigned To", style: TextStyle(color: Colors.grey)),
      SizedBox(height: 5),
      TypeAheadField<UserModel>(
        controller: assigneesSearchController,
        suggestionsCallback: (q) async =>
            _service.fetchUsers(search: q, limit: q.isEmpty ? 5 : 10),
        itemBuilder: (_, s) => Container(
          color: Colors.white,
          child: ListTile(title: Text(s.name)),
        ),
        onSelected: (value) {
          setState(() {
            selectedUser = value;
            assigneesSearchController.text = value.name;
          });
        },
        builder: (_, controller, node) => TextField(
          controller: controller,
          focusNode: node,
          decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: Colors.grey, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: primaryColor, width: 1),
            ),
            hintText: "Select Assignee",
            suffixIcon: selectedUser != null
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        selectedUser = null;
                        assigneesSearchController.clear();
                      });
                    },
                  )
                : null,
          ),
        ),
      ),
    ],
  );

  Widget _dateField(BuildContext context) => TextField(
    controller: activityDateController,
    readOnly: true,

    onTap: () async {
      final d = await showDatePicker(
        context: context,
        initialDate: activityDateController.text.isNotEmpty
            ? DateTime.parse(activityDateController.text)
            : DateTime.now(),
        firstDate: DateTime(2000),
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
      if (d != null) {
        activityDateController.text =
            "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      }
    },
    decoration: InputDecoration(
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: Colors.grey, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: primaryColor, width: 1),
      ),
      hintText: "Select date",
      hintStyle: TextStyle(color: Colors.grey),
    ),
  );

  Widget _submitButton(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isFormValid ? primaryColor : Colors.grey.shade500,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      onPressed: isFormValid
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
              } catch (e) {
                hideLoadingDialog(context);
                Navigator.pop(context);
                Navigator.pop(context);
                CustomSnackbar.showError(context, "Update failed");
              }
            }
          : () {},
      child: const Text("Update"),
    ),
  );

  String stripHtml(String html) {
    final exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false);
    return html.replaceAll(exp, '').trim();
  }
}
