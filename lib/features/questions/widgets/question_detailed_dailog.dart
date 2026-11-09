import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/features/questions/widgets/edit_question.dart';
import 'package:provider/provider.dart';
import '../../../core/services/event_access_rights.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_layout.dart';
import '../../home/providers/home_provider.dart';
import '../../../shared/widgets/forms/field_label.dart';
import '../model/event_question.dart';

class QuestionDetailedDialog extends StatelessWidget {
  final EventQuestion question;
  final int eventId;

  const QuestionDetailedDialog({
    super.key,
    required this.question,
    required this.eventId,
  });

  String getTypeLabel() {
    switch (question.questionType.toLowerCase()) {
      case 'simple_choice':
        return "Single Selection";
      case 'email':
        return "Email";
      case 'name':
        return "Name";
      case 'text_box':
        return "Text Box";
      case 'company':
        return "Company";
      case 'phone':
        return "Phone";
      default:
        return question.questionType;
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeProvider = Provider.of<HomeProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bool hasSettings =
        question.isMandatoryAnswer ||
        question.oncePerOrder ||
        (homeProvider.compat.hasReusableQuestions &&
            (question.isDefault || question.isReusable));
    final bool hasOptions =
        question.answers.isNotEmpty && question.questionType == "simple_choice";

    // A phone in landscape is only ~300-400dp tall: short windows drop the
    // 75% height cap (the dialog's own inset already keeps it on screen) and
    // tighten the header so the details get the room.
    final compact = context.isShortScreen;

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.white,
      insetPadding: compact
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
          : const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: compact
              ? double.infinity
              : MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [AppShadows.panelShadow(isDark)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: compact
                  ? const EdgeInsets.fromLTRB(20, 4, 12, 4)
                  : const EdgeInsets.fromLTRB(20, 16, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Question Details",
                      style: TextStyle(
                        color: AppTheme.textPrimaryOn(isDark),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // Saving a question clears and recreates its answers, so the
                  // pencil needs write on the question and create/delete on
                  // its answers.
                  if (context.watch<AccessRights>().canEditQuestion)
                    IconButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => EditQuestion(
                            eventQuestion: question,
                            eventId: eventId,
                          ),
                        );
                      },
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedPencilEdit02,
                        size: 18,
                        color: primaryColor,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.grey[800]
                            : AppTheme.fieldFill,
                        padding: const EdgeInsets.all(6),
                        minimumSize: const Size(32, 32),
                      ),
                    ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedCancel01,
                      size: 18,
                      color: AppTheme.textPrimaryOn(isDark),
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? Colors.grey[800]
                          : AppTheme.fieldFill,
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(32, 32),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? Colors.grey[800] : const Color(0xFFE0E0E0),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FieldLabel("Title"),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.inputFill(isDark),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text(
                        question.displayName,
                        style: AppTheme.fieldValueStyle(isDark),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const FieldLabel("Question Type"),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.inputFill(isDark),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text(
                        getTypeLabel(),
                        style: AppTheme.fieldValueStyle(isDark),
                      ),
                    ),

                    if (hasSettings) ...[
                      const SizedBox(height: 16),
                      const FieldLabel("Settings"),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.inputFill(isDark),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Column(
                          children: [
                            if (question.isMandatoryAnswer)
                              _flagRow("Mandatory", isDark),
                            if (question.oncePerOrder)
                              _flagRow("Ask once per order", isDark),
                            if (homeProvider.compat.hasReusableQuestions &&
                                question.isDefault)
                              _flagRow("Default Question", isDark),
                            if (homeProvider.compat.hasReusableQuestions &&
                                question.isReusable)
                              _flagRow("Is reusable?", isDark),
                          ],
                        ),
                      ),
                    ],

                    if (hasOptions) ...[
                      const SizedBox(height: 16),
                      const FieldLabel("Options"),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: question.answers
                            .map((e) => _optionChip(e.name))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Read-only flag — these only ever render for a flag that's `true` (see
  /// the `if (question.x)` guards above): the label on the left, its value
  /// plainly spelled out on the right, like a key/value details row rather
  /// than a chip or a checkbox.
  Widget _flagRow(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.secondaryLabelColor(isDark),
            ),
          ),
          const Spacer(),
          Text(
            "Yes",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryOn(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFCE7EE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: primaryColor,
        ),
      ),
    );
  }
}
