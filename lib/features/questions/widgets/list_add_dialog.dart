import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart'
    show LoadingAnimationWidget;
import 'package:mobo_event/features/questions/services/question_service.dart';
import 'package:mobo_event/features/questions/widgets/create_question.dart';
import 'package:mobo_event/shared/helper/helper_method.dart';
import 'package:provider/provider.dart';
import '../../../core/const/app_colors.dart';
import '../../../shared/widgets/loading/loading_widget.dart';
import '../../../shared/widgets/shimmer_card/shimmer_card.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../providers/questions_provider.dart';

class ListAddDialog extends StatefulWidget {
  final List<int> ids;
  final int eventId;
  const ListAddDialog({super.key, required this.ids, required this.eventId});

  @override
  State<ListAddDialog> createState() => _ListAddDialogState();
}

class _ListAddDialogState extends State<ListAddDialog> {
  late List<int> selectedIds = [];

  final services = QuestionService();

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      context.read<QuestionsProvider>().fetchRemainingQuestions(widget.ids);
    });
  }

  bool get isFormValid => selectedIds.isNotEmpty;
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Consumer<QuestionsProvider>(
          builder: (context, provider, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(color: primaryColor.withAlpha(20)),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        "Add Question",
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
                          provider.reset();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),

                Flexible(
                  fit: FlexFit.loose,
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: provider.remainLoading
                        ? SingleChildScrollView(
                            child: Column(
                              children: const [
                                FullCardShimmer(height: 100, radius: 5),
                                SizedBox(height: 10),
                                FullCardShimmer(height: 100, radius: 5),
                                SizedBox(height: 10),
                                FullCardShimmer(height: 100, radius: 5),
                                SizedBox(height: 10),
                                FullCardShimmer(height: 100, radius: 5),
                              ],
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: provider.remainingQuestionList.length,
                            itemBuilder: (_, index) {
                              final q = provider.remainingQuestionList[index];
                              final isChecked = selectedIds.contains(q.id);

                              return Container(
                                width: double.infinity,
                                margin: EdgeInsets.symmetric(vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    width: 1,
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: CheckboxListTile(
                                  value: isChecked,
                                  activeColor: primaryColor,
                                  title: Text(q.title),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        selectedIds.add(q.id);
                                      } else {
                                        selectedIds.remove(q.id);
                                      }
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ),

                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (_) => CreateQuestion(
                          eventId: widget.eventId,
                          previousIds: widget.ids,
                        ),
                      );
                    },
                    child: const Text("Create Question"),
                  ),
                ),
                SizedBox(height: 20),
                isFormValid
                    ? Container(
                        height: 50,
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,

                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          onPressed: () async {
                            try {
                              loadingDialog(
                                context,
                                "Adding",
                                "Please wait...",
                                LoadingAnimationWidget.fourRotatingDots(
                                  color: primaryColor,
                                  size: 30,
                                ),
                              );

                              await services.addQuestions(
                                selectedIds,
                                widget.eventId,
                              );
                              provider.reset();

                              await Provider.of<QuestionsProvider>(
                                context,
                                listen: false,
                              ).fetchQuestions(widget.eventId);

                              hideLoadingDialog(context);
                              Navigator.pop(context);
                              CustomSnackbar.showSuccess(
                                context,
                                "Successfully added",
                              );
                            } catch (e) {
                              hideLoadingDialog(context);
                              Navigator.pop(context);
                              CustomSnackbar.showError(
                                context,
                                cleanedError(e.toString()),
                              );
                            }
                          },
                          child: const Text("Save"),
                        ),
                      )
                    : SizedBox.shrink(),
                SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }
}
