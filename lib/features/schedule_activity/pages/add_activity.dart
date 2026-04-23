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
  final TextEditingController activitySearchController =
  TextEditingController();
  final TextEditingController assigneesSearchController =
  TextEditingController();

  ActivityTypeModel? selectedActivity;
  UserModel? selectedUser;

  FocusNode activityNode = FocusNode();
  FocusNode userNode = FocusNode();

  final _service = EventActivityServices();

  @override
  void initState() {
    super.initState();
    activityDateController.addListener(() => setState(() {}));
  }

  bool get isFormValid =>
      selectedActivity != null &&
          selectedUser != null &&
          activityDateController.text.isNotEmpty&&summaryController.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20,vertical: 10),
              decoration:
              BoxDecoration(color: primaryColor.withAlpha(20)),
              child: Row(
                children: [
                  const Text(
                    "Create Activity",
                    style: TextStyle(
                        color: primaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Activity Type",style: TextStyle(color: Colors.grey),),
                  const SizedBox(height: 5),


                  TypeAheadField<ActivityTypeModel>(
                    controller: activitySearchController,
                    debounceDuration:
                    const Duration(milliseconds: 400),

                    suggestionsCallback: (q) async {
                      return await _service.fetchActivityTypes(
                        search: q,
                        limit: q.isEmpty ? 3 : 10,
                      );
                    },

                    itemBuilder: (context, s) =>
                        Container(
                          color: Colors.white,
                            child: ListTile(title: Text(s.name))),

                    onSelected: (value) {
                      setState(() {
                        selectedActivity = value;
                        activitySearchController.text = value.name;
                      });
                    },

                    builder: (context, controller, node) {
                      activityNode = node;
                      return TextField(
                        controller: controller,
                        focusNode: node,
                        decoration: InputDecoration(
                          hintText: "Select Activity",
                            hintStyle: TextStyle(
                                color: Colors.grey,
                                fontSize: 13
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
                      );
                    },
                  ),

                  const SizedBox(height: 15),

                  const Text("Assigned To",style: TextStyle(
                    color: Colors.grey
                  ),),
                  SizedBox(height: 5,),
                  TypeAheadField<UserModel>(
                    controller: assigneesSearchController,
                    debounceDuration:
                    const Duration(milliseconds: 300),

                    suggestionsCallback: (q) async {
                      return await _service.fetchUsers(
                        search: q,
                        limit: q.isEmpty ? 5 : 10,
                      );
                    },

                    itemBuilder: (context, s) =>
                        Container(
                          color: Colors.white,
                            child: ListTile(title: Text(s.name))),

                    onSelected: (value) {
                      setState(() {
                        selectedUser = value;
                        assigneesSearchController.text = value.name;
                      });
                    },

                    builder: (context, controller, node) {
                      userNode = node;
                      return TextField(
                        controller: controller,
                        focusNode: node,
                        decoration: InputDecoration(
                          hintText: "Select Assignee",
                            hintStyle: TextStyle(
                                color: Colors.grey,
                                fontSize: 13
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
                      );
                    },
                  ),

                  const SizedBox(height: 15),

                  const Text("Summary",style: TextStyle(color: Colors.grey),),
                  SizedBox(height: 5,),
                  TextField(
                      controller: summaryController,
                    onChanged: (value){
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
                      hintText: "eg:Discuss Proposal",
                        hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 13
                        )
                    ),
                  ),

                  const SizedBox(height: 15),



                  const Text("Date",style: TextStyle(
                    color: Colors.grey
                  ),),
                  SizedBox(height: 5,),
                  TextField(
                    controller: activityDateController,
                    readOnly: true,
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
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
                                headerBackgroundColor:primaryColor,
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
                    decoration:
                     InputDecoration(
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
                        hintText: "Select date",
                       hintStyle: TextStyle(
                         color: Colors.grey,
                         fontSize: 13
                       )

                     ),
                  ),
                  const SizedBox(height: 15),
                  const Text("Note",style: TextStyle(
                    color: Colors.grey
                  ),),
                  SizedBox(height: 5,),
                  TextField(controller: noteController,
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
                        hintText: "Log notes...",
                        hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 13
                        )

                    ),
                  ),



                  const SizedBox(height: 25),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFormValid
                            ? primaryColor
                            : Colors.grey.shade500,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: isFormValid
                          ? ()async {





                        try {

                          /// loading
                          loadingDialog(context, "Create Events",
                              "Please wait while we Creating Event",
                              LoadingAnimationWidget.fourRotatingDots(
                                  color: primaryColor, size: 30));


                          /// create event Activity
                          await _service.createActivity(
                            resId: widget.resId,
                            model: widget.model,
                            typeId: selectedActivity!.id,
                            userId: selectedUser!.id,
                            summary: summaryController.text,
                            note: noteController.text,
                            deadline: activityDateController.text,
                          );
                          final homeProvider =Provider.of<HomeProvider>(context, listen: false);
                          await homeProvider.gettingStages();
                          hideLoadingDialog(context);
                          Navigator.pop(context);
                          Navigator.pop(context);
                          /// success
                          CustomSnackbar.showSuccess(context, "Success fully created activity");
                        } catch (e) {
                          hideLoadingDialog(context);
                          Navigator.pop(context);
                          Navigator.pop(context);
                          /// error
                          CustomSnackbar.showError(context, "failed to create activity");
                        }
                      }
                          : (){},
                      child: const Text("Create"),
                    ),
                  ),
                  SizedBox(height: 20,)
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
