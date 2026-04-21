import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/features/questions/providers/questions_provider.dart';
import 'package:mobo_event/shared/widgets/action_button.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';

import '../../../core/const/app_colors.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../../shared/widgets/loading/loading_widget.dart';
import '../../../shared/widgets/shimmer_card/shimmer_card.dart';
import '../services/question_service.dart';
import '../widgets/create_question.dart';
import '../widgets/list_add_dialog.dart';
import '../widgets/question_card.dart';
import '../widgets/question_detailed_dailog.dart';

class EventQuestionPage extends StatefulWidget {
  final int eventId;

  const EventQuestionPage({super.key, required this.eventId});

  @override
  State<EventQuestionPage> createState() => _EventQuestionPageState();
}

class _EventQuestionPageState extends State<EventQuestionPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<QuestionsProvider>().fetchQuestions(widget.eventId);
    });
  }

  final services = QuestionService();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 10, right: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Questions Information",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: Consumer<QuestionsProvider>(
              builder: (context, provider, child) {
                return buildContent(provider, context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget buildContent(QuestionsProvider provider, BuildContext context) {
    if (provider.isLoading) {
      return SingleChildScrollView(
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
      );
    }
    if (provider.questionList.isNotEmpty) {
      return SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: NeverScrollableScrollPhysics(),
              itemCount: provider.questionList.length,
              itemBuilder: (context, index) {
                return QuestionCard(
                  question: provider.questionList[index],
                  onDelete: () async {
                    try {
                      loadingDialog(
                        context,
                        "Deleting ",
                        "Please wait...",
                        LoadingAnimationWidget.fourRotatingDots(
                          color: primaryColor,
                          size: 30,
                        ),
                      );

                      await services.removeQuestion(
                        widget.eventId,
                        provider.questionList[index].id,
                      );

                      await Provider.of<QuestionsProvider>(
                        context,
                        listen: false,
                      ).fetchQuestions(widget.eventId);

                      hideLoadingDialog(context);
                    } catch (e) {
                      hideLoadingDialog(context);
                      CustomSnackbar.showError(context, "Error While deleting");
                    }
                  },
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => QuestionDetailedDialog(
                        question: provider.questionList[index],
                        eventId: widget.eventId,
                      ),
                    );
                  },
                );
              },
            ),

            SizedBox(height: 10),
            actionButton(
              label: "Add Questions",
              icon: HugeIcons.strokeRoundedAdd01,
              onPressed: () async {
                final ids = provider.questionList
                    .map((single) => single.id)
                    .toList();
                final session = await OdooSessionManager.getCurrentSession();

                final version = session!.odooSession.serverVersion;

                String odooVersion = version;

                if (odooVersion == '19') {
                  showDialog<String>(
                    context: context,
                    builder: (_) =>
                        ListAddDialog(ids: ids, eventId: widget.eventId),
                  );
                } else {
                  showDialog(
                    context: context,
                    builder: (_) => CreateQuestion(
                      eventId: widget.eventId,
                      previousIds: ids,
                    ),
                  );
                }
              },
            ),

            SizedBox(height: 20),
          ],
        ),
      );
    }

    if (provider.questionList.isEmpty) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 100),
              const HugeIcon(
                icon: HugeIcons.strokeRoundedQuestion,
                size: 60,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text("No Question Information found"),
              const SizedBox(height: 6),
              const SizedBox(height: 16),

              _actionButton(
                label: "Create Question",
                icon: HugeIcons.strokeRoundedAdd01,
                onPressed: () async {
                  final ids = provider.questionList
                      .map((single) => single.id)
                      .toList();

                  final session = await OdooSessionManager.getCurrentSession();
                  final version = session!.odooSession.serverVersion;
                  String odooVersion = version;

                  if (odooVersion == '19') {
                    showDialog<String>(
                      context: context,
                      builder: (_) =>
                          ListAddDialog(ids: ids, eventId: widget.eventId),
                    );
                  } else {
                    showDialog(
                      context: context,
                      builder: (_) => CreateQuestion(
                        eventId: widget.eventId,
                        previousIds: ids,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      );
    }
    return SingleChildScrollView(
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
    );
  }

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
        textStyle: TextStyle(fontSize: 12),
      ),
    );
  }
}
