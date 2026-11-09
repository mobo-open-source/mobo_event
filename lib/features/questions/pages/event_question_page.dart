import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/features/questions/providers/questions_provider.dart';
import 'package:mobo_event/shared/widgets/section_list_state.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';

import '../../../core/const/app_colors.dart';
import '../../../core/services/event_access_rights.dart';
import '../../../core/utils/odoo_compat.dart';
import '../../../core/utils/screen_layout.dart';
import '../../../shared/helper/helper_method.dart';
import '../../../shared/widgets/dialogs/common_dialog.dart';
import '../../../shared/widgets/loading/loading_widget.dart';
import '../../../shared/widgets/shimmer_card/shimmer_card.dart';
import '../../home/providers/home_provider.dart';
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
  // Nothing is fetched here: the Details screen loads the questions together
  // with the rest of the event, and reloads them on refresh.
  final services = QuestionService();

  /// True while an Add tap is getting ready to open its dialog, so a second tap
  /// doesn't start another.
  bool _opening = false;

  /// Odoo 19 and newer pick from reusable questions; 17/18 create one directly.
  ///
  /// The picker's list is in hand before its dialog opens, so the dialog shows
  /// the list rather than a skeleton while it loads: usually it already is (the
  /// Details screen fetches it as the questions arrive), and otherwise it is
  /// fetched here first, and a failure is a message instead of an empty dialog.
  Future<void> _addQuestion(QuestionsProvider provider) async {
    if (_opening) return;
    _opening = true;
    try {
      final ids = provider.questionList.map((single) => single.id).toList();
      final compat = await OdooCompat.current();
      if (!mounted) return;

      if (compat.hasReusableQuestions) {
        if (!provider.hasFreshRemaining(ids)) {
          await provider.fetchRemainingQuestions(ids);
          if (!mounted) return;
        }
        showDialog<String>(
          context: context,
          builder: (_) => ListAddDialog(ids: ids, eventId: widget.eventId),
        );
      } else {
        showDialog(
          context: context,
          builder: (_) =>
              CreateQuestion(eventId: widget.eventId, previousIds: ids),
        );
      }
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(context, cleanedError(e.toString()));
    } finally {
      _opening = false;
    }
  }

  /// Whether this account may add a question the way this server's release
  /// does it (see [AccessRights.canAddQuestion]).
  bool _canAdd(BuildContext context) => context
      .watch<AccessRights>()
      .canAddQuestion(context.watch<HomeProvider>().compat);

  @override
  Widget build(BuildContext context) {
    // No side padding, same as the Tickets tab's — otherwise its header and
    // cards sit narrower than the Tickets tab's and don't line up with it.
    return Container(
      width: double.infinity,
      child: Consumer<QuestionsProvider>(
        builder: (context, provider, child) {
          final hasQuestions =
              !provider.isLoading && provider.questionList.isNotEmpty;
          final canAdd = _canAdd(context);
          final page = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: "Questions Information",
                onAdd: hasQuestions && canAdd
                    ? () => _addQuestion(provider)
                    : null,
              ),
              const SizedBox(height: 16),
              Expanded(child: buildContent(provider, context)),
            ],
          );
          // One scrolling column; on a wide landscape window it is capped and
          // centred rather than stretched across the whole width.
          return context.isLandscape ? ConstrainedContent(child: page) : page;
        },
      ),
    );
  }

  /// Build content
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
                  // Removing a question rewrites the event's `question_ids`.
                  onDelete: !context.watch<AccessRights>().canRemoveQuestion
                      ? null
                      : () async {
                          final question = provider.questionList[index];
                          final confirm = await CommonDialog.confirm(
                            context,
                            title: 'Delete Question',
                            message:
                                'Are you sure you want to delete "${question.title}"?',
                            confirmText: 'Delete',
                          );
                          if (confirm != true || !context.mounted) return;

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
                          } catch (_) {
                            hideLoadingDialog(context);
                            CustomSnackbar.showError(
                              context,
                              "Error While deleting",
                            );
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
          ],
        ),
      );
    }

    if (provider.questionList.isEmpty) {
      return CenteredSectionBody(
        child: EmptySectionState(
          icon: HugeIcons.strokeRoundedQuestion,
          title: "No questions yet",
          actionLabel: "Add Question",
          onAction: _canAdd(context) ? () => _addQuestion(provider) : null,
        ),
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
}
