
import 'package:flutter/material.dart';
import 'package:mobo_event/features/registration/model/demo_question_answer.dart';
import 'package:mobo_event/features/registration/provider/registration_provider.dart';
import 'package:mobo_event/features/registration/services/registration_services.dart';
import 'package:mobo_event/features/registration/widget/type_head.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';

import '../../../core/const/app_colors.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../event/model/fetch_model.dart';
import '../../event/widget/field.dart';
import '../../questions/model/event_question.dart';

class QuestionDialog extends StatefulWidget {
  final int eventId;
  const QuestionDialog({super.key,required this.eventId});

  @override
  State<QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<QuestionDialog> {

  final questionController = TextEditingController();
  final selectionController = TextEditingController();
  final answerController = TextEditingController();
  EventQuestion? selectedQuestion;
  FetchModel? selectedSelection;
  final services = RegistrationServices();


  @override
  void dispose() {
    questionController.dispose();
    selectionController.dispose();
    answerController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {



    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: primaryColor.withAlpha(20),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  "Add Question & Answer",
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label("Question type"),
                  AppTypeAhead<EventQuestion>(
                    controller: questionController,
                    hint: "Search Question type",
                    selectedValue: selectedQuestion,
                    suggestionsCallback: (value) async{
                      final session = await OdooSessionManager.getCurrentSession();

                      final version = session!.odooSession.serverVersion;

                      String odooVersion = version;


                      return services.getTypeHeadQuestionSearchList(
                        model: "event.question",
                        search: value,
                        domain: [
                        if(odooVersion =='19')  ['event_ids', '=',widget.eventId],
                          if(odooVersion == '18')['event_id', '=',widget.eventId]
                        ],
                      );
                    },
                    itemLabel: (item) => item.displayName ?? "",
                    onSelected: (item) {

                      setState(() {
                        answerController.clear();
                        selectedQuestion = item;
                        questionController.text = item.displayName ?? "";
                      });
                    },
                    fieldBuilder: (context, controller, focusNode, isSelected, clear) {
                      return Field(
                        controller: controller,
                        focusNode: focusNode,
                        readOnly: isSelected,
                        hint: "Search Question type",
                        suffixIcon: isSelected
                            ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              questionController.clear();
                              selectedQuestion = null;
                              answerController.clear();

                            });
                          },) : null,);
                    },
                  ),
                  SizedBox(height: 10,),
              if(selectedQuestion!=null&&selectedQuestion!.questionType =="simple_choice") ...[

                _label("Selection"),
                AppTypeAhead<FetchModel>(
                  controller: selectionController,
                  hint: "Search Source",
                  selectedValue: selectedSelection,
                  suggestionsCallback: (value) {
                    return services.getTypeHeadSearchList(
                      model: "event.question.answer",
                      search: value,
                      domain: [
                        ['question_id', '=', selectedQuestion!.id]
                      ],
                    );
                  },
                  itemLabel: (item) => item.name ?? "",
                  onSelected: (item) {
                    setState(() {
                      selectedSelection = item;
                      selectionController.text = item.name ?? "";
                      answerController.clear();
                    });
                  },
                  fieldBuilder: (context, controller, focusNode, isSelected, clear) {
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
                            selectionController.clear();
                            selectedSelection = null;
                            answerController.clear();

                          });
                        },) : null,);
                  },
                ),

              ],
                  SizedBox(height: 10,),
                  if(selectedQuestion!=null&&selectedQuestion!.questionType !="simple_choice")...[
                    _label("Answer"),
                    Field(
                      controller: answerController,
                      hint: "Enter Answer",
                    ),
                  ],
                  SizedBox(height: 15,),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      onPressed: () {
                        if (selectedQuestion == null) {
                          CustomSnackbar.showError(context, "Please select a question");
                          return;
                        }
                        if (selectedQuestion!.questionType == "simple_choice" &&
                            selectedSelection == null) {
                          CustomSnackbar.showError(context, "Please select an option");
                          return;
                        }
                        if (selectedQuestion!.questionType != "simple_choice" &&
                            answerController.text.trim().isEmpty) {
                          CustomSnackbar.showError(context, "Please enter an answer");
                          return;
                        }
                        final question = DemoQuestionAnswer(
                          questionId: selectedQuestion!.id,
                          valueTextBox: answerController.text.isNotEmpty? answerController.text:false,
                          valueAnswerId: selectedSelection!=null?selectedSelection!.id:false,
                          questionName: selectedQuestion!.displayName,
                          answer: answerController.text,
                          selectedValue: selectedSelection!=null?selectedSelection!.name:null,
                        );
                        Provider.of<RegistrationProvider>(context, listen: false).saveQuestion(question);
                        CustomSnackbar.showSuccess(context, "New Question added");
                        Navigator.pop(context);
                      },
                        child: const Text(
                          " Save Question",
                          style: TextStyle(fontSize: 16),
                        ),),
                  )

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _label(String t) =>
      Text(t, style: const TextStyle(color: Colors.grey));
}
