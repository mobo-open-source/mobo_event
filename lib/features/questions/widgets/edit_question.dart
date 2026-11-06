import 'package:flutter/foundation.dart';
import '../../../shared/widgets/toggles/mobo_checkbox.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/features/questions/model/event_question.dart';
import 'package:mobo_event/features/questions/services/question_service.dart';
import 'package:mobo_event/shared/helper/helper_method.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';
import '../../../core/const/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_layout.dart';
import '../../../shared/widgets/loading/loading_widget.dart';
import '../../home/providers/home_provider.dart';
import '../../event/widget/field.dart';
import '../providers/questions_provider.dart';
import '../../../shared/widgets/forms/field_label.dart';
import '../../../shared/widgets/forms/mobo_select_field.dart';

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

  /// What the dialog held when it opened. Save stays disabled until the
  /// current values differ from it.
  late final Map<String, Object?> _initialValues;

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

    _initialValues = _currentValues();
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

  /// Every value Save writes, reduced to something `==` can compare.
  Map<String, Object?> _currentValues() => {
    'title': nameController.text.trim(),
    'type': selectedLabel,
    'mandatory': isMandatory,
    'askOnce': askOnce,
    'default': isDefault,
    'reusable': isReusable,
    // Answer fields are single-line, so joining on a newline keeps the
    // whole list — order included — comparable as one string.
    'answers': answerControllers.map((c) => c.text.trim()).join('\n'),
  };

  bool get canSubmit =>
      isFormValid && !mapEquals(_currentValues(), _initialValues);

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final compact = context.isShortScreen;
    return Dialog(
      backgroundColor: AppTheme.surface(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: 18,
        vertical: compact ? 8 : 10,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) =>
            _content(context, constraints.maxHeight),
      ),
    );
  }

  Widget _content(BuildContext context, double avail) {
    final homeProvider = Provider.of<HomeProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // A phone in landscape is only ~300-400dp tall, so the portrait recipe
    // (header + body + footer inside 75% of the height) leaves the body a
    // sliver. Short windows give the dialog the whole height, let the title
    // scroll away with the fields and tighten the pinned footer.
    final compact = context.isShortScreen;
    // Height the dialog really has: the window minus the keyboard and insets.
    // Under 190 even the portrait recipe cannot fit header + footer, and under
    // 124 a pinned footer would leave the fields less than a field's height,
    // so the footer then scrolls with the fields instead of being pinned.
    final dense = compact || avail < 190;
    final tiny = dense && avail < 124;

    final header = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 0 : 20,
        vertical: dense ? 0 : 10,
      ),
      child: Row(
        children: [
          Text(
            "Edit Question",
            style: TextStyle(
              color: AppTheme.textPrimaryOn(isDark),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            visualDensity: dense ? VisualDensity.compact : null,
            icon: Icon(
              Icons.close,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );

    final footer = Padding(
      padding: tiny
          ? const EdgeInsets.fromLTRB(0, 8, 0, 10)
          : dense
          ? const EdgeInsets.fromLTRB(10, 6, 10, 10)
          : const EdgeInsets.all(10),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: primaryColor,
            disabledBackgroundColor: AppTheme.disabledButtonFillOn(isDark),
            disabledForegroundColor: AppTheme.disabledButtonText,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          onPressed: canSubmit
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
                      answers: answerControllers.map((e) => e.text).toList(),
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
              : null,
          child: const Text(
            "Save Question",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );

    final form = SingleChildScrollView(
      keyboardDismissBehavior: dense
          ? ScrollViewKeyboardDismissBehavior.onDrag
          : ScrollViewKeyboardDismissBehavior.manual,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dense) header,
          const FieldLabel("Question Title", isRequired: true),
          const SizedBox(height: 6),
          Field(
            controller: nameController,
            hint: "eg:Do you have any diet restriction?",
            onChanged: (value) {
              nameController.text = value;
              setState(() {});
            },
          ),

          const SizedBox(height: 16),

          const FieldLabel("Question Type"),
          const SizedBox(height: 6),

          MoboSingleSelectField<String>(
            selected: selectedLabel,
            options: questionTypeMap.keys
                .map((label) => MoboSelectOption(value: label, label: label))
                .toList(),
            hintText: 'Select question type',
            panelTitle: 'Select Question Type',
            allowClear: false,
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                selectedLabel = value;
              });
            },
          ),

          const SizedBox(height: 16),

          if (selectedLabel == "Selection") ...[
            const FieldLabel("Answers", isRequired: true),
            const SizedBox(height: 8),

            Column(
              children: List.generate(
                answerControllers.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Field(
                    controller: answerControllers[index],
                    hint: "Option ${index + 1}",
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
          if (homeProvider.compat.hasReusableQuestions)
            buildCheckbox("Default question", isDefault, (v) {
              setState(() {
                isDefault = v;
                if (v) {
                  isReusable = v;
                }
              });
            }),
          if (homeProvider.compat.hasReusableQuestions)
            buildCheckbox("Is reusable", isReusable, (v) {
              if (isDefault && !v) return;
              setState(() => isReusable = v);
            }),

          const SizedBox(height: 16),
          if (tiny) footer,
        ],
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: dense
            ? double.infinity
            : MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!dense) header,

          dense
              ? Flexible(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: form,
                  ),
                )
              : Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: form,
                  ),
                ),

          if (!tiny) footer,
          if (!dense) const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget buildCheckbox(String title, bool value, Function(bool) onChanged) {
    return MoboCheckboxTile(
      title: title,
      value: value,
      onChanged: onChanged,
      checkboxAtEnd: true,
    );
  }
}
