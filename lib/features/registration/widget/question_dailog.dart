import 'package:flutter/material.dart';
import 'package:mobo_event/features/registration/model/demo_question_answer.dart';
import 'package:mobo_event/features/registration/provider/registration_provider.dart';
import 'package:mobo_event/features/registration/services/registration_services.dart';
import 'package:mobo_event/shared/widgets/forms/field_label.dart';
import 'package:mobo_event/shared/widgets/forms/mobo_select_field.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';

import '../../../core/const/app_colors.dart';
import '../../../core/utils/odoo_compat.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_layout.dart';
import '../../event/model/fetch_model.dart';
import '../../event/widget/field.dart';
import '../../questions/model/event_question.dart';

class QuestionDialog extends StatefulWidget {
  final int eventId;
  const QuestionDialog({super.key, required this.eventId});

  @override
  State<QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<QuestionDialog> {
  final answerController = TextEditingController();
  EventQuestion? selectedQuestion;
  FetchModel? selectedSelection;
  final services = RegistrationServices();

  /// Save is enabled once the chosen question has what it needs: an option
  /// for a choice question, a non-blank answer for any other type.
  bool get _canSave {
    final question = selectedQuestion;
    if (question == null) return false;
    if (question.questionType == "simple_choice") {
      return selectedSelection != null;
    }
    return answerController.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final short = context.isShortScreen;

    final title = Text(
      "Add Question & Answer",
      style: TextStyle(
        color: AppTheme.textPrimaryOn(isDark),
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );

    final closeButton = IconButton(
      icon: const Icon(Icons.close),
      onPressed: () {
        Navigator.pop(context);
      },
    );

    final fields = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label("Question type"),
        MoboSingleSelectField<EventQuestion>(
          selected: selectedQuestion,
          selectedLabel: selectedQuestion?.displayName,
          hintText: 'Select question',
          panelTitle: 'Select Question',
          search: (q) async {
            final compat = await OdooCompat.current();

            return (await services.getTypeHeadQuestionSearchList(
                  model: "event.question",
                  search: q,
                  domain: [
                    [compat.questionEventField, '=', widget.eventId],
                  ],
                  limit: 20,
                ))
                .map((m) => MoboSelectOption(value: m, label: m.displayName))
                .toList();
          },
          onChanged: (item) {
            // Re-picking the current question keeps its answer.
            if (item == selectedQuestion) return;

            // The answer and the chosen option belong to the old
            // question, so picking another one (or clearing it with
            // the X) drops both.
            setState(() {
              selectedQuestion = item;
              selectedSelection = null;
              answerController.clear();
            });
          },
        ),
        SizedBox(height: 10),
        if (selectedQuestion != null &&
            selectedQuestion!.questionType == "simple_choice") ...[
          _label("Selection"),
          MoboSingleSelectField<FetchModel>(
            selected: selectedSelection,
            selectedLabel: selectedSelection?.name,
            hintText: 'Select option',
            panelTitle: 'Select Option',
            search: (q) async =>
                (await services.getTypeHeadSearchList(
                      model: "event.question.answer",
                      search: q,
                      domain: [
                        ['question_id', '=', selectedQuestion!.id],
                      ],
                      limit: 20,
                    ))
                    .map((m) => MoboSelectOption(value: m, label: m.name ?? ''))
                    .toList(),
            onChanged: (item) {
              setState(() {
                selectedSelection = item;
                answerController.clear();
              });
            },
          ),
        ],
        SizedBox(height: 10),
        if (selectedQuestion != null &&
            selectedQuestion!.questionType != "simple_choice") ...[
          _label("Answer"),
          Field(
            controller: answerController,
            hint: "Enter Answer",
            onChanged: (_) => setState(() {}),
          ),
        ],
      ],
    );

    final saveButton = SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          // Same disabled look as the create/edit attendee form's submit.
          disabledBackgroundColor: isDark
              ? Colors.grey[700]
              : Colors.grey.shade400,
          disabledForegroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: short ? 10 : 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: !_canSave
            ? null
            : () {
                final question = DemoQuestionAnswer(
                  questionId: selectedQuestion!.id,
                  valueTextBox: answerController.text.isNotEmpty
                      ? answerController.text
                      : false,
                  valueAnswerId: selectedSelection != null
                      ? selectedSelection!.id
                      : false,
                  questionName: selectedQuestion!.displayName,
                  answer: answerController.text,
                  selectedValue: selectedSelection != null
                      ? selectedSelection!.name
                      : null,
                );
                Provider.of<RegistrationProvider>(
                  context,
                  listen: false,
                ).saveQuestion(question);
                CustomSnackbar.showSuccess(context, "New Question added");
                Navigator.pop(context);
              },
        child: const Text("Save Question", style: TextStyle(fontSize: 16)),
      ),
    );

    // A phone in landscape leaves ~100–200dp above the keyboard, which a
    // pinned title bar plus a footer would take most of. So there the title
    // row scrolls with the fields (always — switching on the keyboard would
    // rebuild the fields and drop focus), and only the compact Save footer
    // stays pinned. Under ~150dp even that is too much (a Column can't give
    // the fields a negative height), so Save moves to the end of the scroll;
    // it is in the same Column slot either way, so the focused field keeps
    // its focus while that happens.
    if (short) {
      return Dialog(
        backgroundColor: AppTheme.surface(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        // The dialog normally eases to the keyboard's height over 100ms, but
        // the field's scroll-into-view runs the moment the keyboard appears —
        // against the not-yet-shrunk dialog — and then the dialog closes in
        // over it. Snapping lets the scroll see the final height.
        insetAnimationDuration: Duration.zero,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final squeezed = constraints.maxHeight < 150;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [title, const Spacer(), closeButton]),
                        fields,
                        if (squeezed)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: saveButton,
                          ),
                      ],
                    ),
                  ),
                ),
                if (!squeezed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: saveButton,
                  ),
              ],
            );
          },
        ),
      );
    }

    return Dialog(
      backgroundColor: AppTheme.surface(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Row(children: [title, const Spacer(), closeButton]),
          ),

          Flexible(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(child: fields),
            ),
          ),
          // The fields scroll; Save stays pinned below them.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: saveButton,
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: FieldLabel(t, isRequired: true),
  );
}
