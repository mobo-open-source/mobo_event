import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/features/questions/model/event_question.dart';
import 'package:mobo_event/features/questions/services/question_service.dart';
import 'package:mobo_event/shared/helper/helper_method.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';
import '../../../core/const/app_colors.dart';
import '../../../shared/widgets/loading/loading_widget.dart';
import '../../home/providers/home_provider.dart';
import '../providers/questions_provider.dart';
import 'list_add_dialog.dart';

class EditQuestion extends StatefulWidget {
  final EventQuestion eventQuestion;
  final int eventId;

  const EditQuestion({
    super.key,
    required this.eventQuestion,
    required this.eventId,
  });

  @override
  State<EditQuestion> createState() => _EditQuestionState();
}

class _EditQuestionState extends State<EditQuestion> {
  TextEditingController nameController = TextEditingController();

  bool isMandatory = false;
  bool askOnce = false;
  bool isDefault = false;
  bool isReusable = true;
  final services = QuestionService();

  String selectedLabel = "Selection";

  List<TextEditingController> answerControllers = [TextEditingController()];

  Map<String, String> questionTypeMap = {
    "Selection": "simple_choice",
    "Text Input": "text_box",
    "Name": "name",
    "Email": "email",
    "Phone": "phone",
    "Company": "company_name",
  };
  @override
  void dispose() {
    nameController.dispose();
    for (var c in answerControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    nameController.addListener(() => setState(() {}));

    nameController.text = widget.eventQuestion.displayName;
    isMandatory = widget.eventQuestion.isMandatoryAnswer;
    isReusable = widget.eventQuestion.isReusable;
    isDefault = widget.eventQuestion.isDefault;
    askOnce = widget.eventQuestion.oncePerOrder;

    selectedLabel = questionTypeMap.entries
        .firstWhere(
          (e) => e.value == widget.eventQuestion.questionType,
          orElse: () => const MapEntry("Selection", "simple_choice"),
        )
        .key;

    answerControllers.clear();

    if (widget.eventQuestion.answers.isNotEmpty) {
      for (var answer in widget.eventQuestion.answers) {
        final controller = TextEditingController(text: answer.name);
        controller.addListener(() => setState(() {}));
        answerControllers.add(controller);
      }
    } else {
      final controller = TextEditingController();
      controller.addListener(() => setState(() {}));
      answerControllers.add(controller);
    }
  }

  bool get isFormValid {
    if (nameController.text.trim().isEmpty) return false;

    if (selectedLabel == "Selection") {
      for (var c in answerControllers) {
        if (c.text.trim().isEmpty) return false;
      }
    }
    return true;
  }

  void addAnswerField() {
    if (answerControllers.last.text.trim().isEmpty) return;

    final controller = TextEditingController();
    controller.addListener(() => setState(() {}));

    setState(() {
      answerControllers.add(controller);
    });
  }

  @override
  Widget build(BuildContext context) {
    final homeProvider = Provider.of<HomeProvider>(context, listen: false);
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(color: primaryColor.withAlpha(40)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  const Text(
                    "Edit Question",
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
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Question Title *",
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameController,

                        onChanged: (value) {
                          nameController.text = value;
                          setState(() {});
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
                          hintText: "eg:Do you have any diet restriction?",
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        "Question Type",
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 6),

                      DropdownButtonFormField<String>(
                        value: selectedLabel,
                        dropdownColor: Colors.white,

                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(5),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                              width: 0.5,
                            ),
                          ),

                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(5),
                            borderSide: BorderSide(
                              color: Colors.grey,
                              width: 0.5,
                            ),
                          ),
                        ),
                        items: questionTypeMap.keys.map((label) {
                          return DropdownMenuItem(
                            value: label,
                            child: Text(label),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedLabel = value!;
                          });
                        },
                      ),

                      const SizedBox(height: 16),

                      if (selectedLabel == "Selection") ...[
                        const Text(
                          "Answers *",
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),

                        Column(
                          children: List.generate(
                            answerControllers.length,
                            (index) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: TextField(
                                controller: answerControllers[index],
                                onChanged: (value) {
                                  if (value.trim().isEmpty && index != 0) {
                                    setState(() {
                                      answerControllers.removeAt(index);
                                    });
                                  } else {
                                    setState(() {
                                      answerControllers[index].text = value;
                                    });
                                  }
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
                                  hintText: "Option ${index + 1}",
                                  hintStyle: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        TextButton.icon(
                          onPressed: answerControllers.last.text.trim().isEmpty
                              ? null
                              : addAnswerField,
                          icon: const Icon(Icons.add),
                          label: const Text("Add Answer"),
                        ),
                      ],

                      buildCheckbox(
                        "Mandatory",
                        isMandatory,
                        (v) => setState(() => isMandatory = v),
                      ),
                      buildCheckbox(
                        "Ask once per order",
                        askOnce,
                        (v) => setState(() => askOnce = v),
                      ),
                      if (homeProvider.version.contains('19'))
                        buildCheckbox("Default question", isDefault, (v) {
                          setState(() {
                            isDefault = v;
                            if (v) {
                              isReusable = v;
                            }
                          });
                        }),
                      if (homeProvider.version.contains('19'))
                        buildCheckbox("Is reusable", isReusable, (v) {
                          if (isDefault && !v) return;
                          setState(() => isReusable = v);
                        }),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(10),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFormValid
                        ? primaryColor
                        : Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isFormValid
                      ? () async {
                          try {
                            loadingDialog(
                              context,
                              "Updating ",
                              "Please wait...",
                              LoadingAnimationWidget.fourRotatingDots(
                                color: primaryColor,
                                size: 30,
                              ),
                            );

                            await services.editQuestions(
                              questionId: widget.eventQuestion.id,
                              title: nameController.text.trim(),
                              isMandatory: isMandatory,
                              questionType: questionTypeMap[selectedLabel]!,
                              oncePerOrder: askOnce,
                              isDefault: isDefault,
                              isReusable: isReusable,
                              answers: answerControllers
                                  .map((e) => e.text)
                                  .toList(),
                              eventId: widget.eventId,
                            );
                            await Provider.of<QuestionsProvider>(
                              context,
                              listen: false,
                            ).fetchQuestions(widget.eventId);

                            hideLoadingDialog(context);

                            CustomSnackbar.showSuccess(
                              context,
                              "Updated and saved successfully",
                            );

                            Navigator.pop(context);
                            Navigator.pop(context);
                          } catch (e) {
                            hideLoadingDialog(context);
                            Navigator.pop(context);
                            Navigator.pop(context);
                            final message = cleanedError(e.toString());
                            CustomSnackbar.showError(context, message);
                          }
                        }
                      : () {},
                  child: const Text(
                    "Save Question",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget buildCheckbox(String title, bool value, Function(bool) onChanged) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      value: value,
      onChanged: (v) => onChanged(v!),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}
