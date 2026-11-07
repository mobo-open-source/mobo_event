import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_event/features/registration/model/demo_question_answer.dart';

import '../../../core/theme/app_theme.dart';

/// Same card shell/layout as the event's "Questions Information" list
/// ([QuestionCard]) — plain icon, title + grey subtitle, trailing "⋮" with a
/// single red Delete item — instead of this card's previous, differently
/// styled look (tinted icon box, inline delete icon button).
class QuestionAnswerCard extends StatelessWidget {
  final DemoQuestionAnswer questionAnswer;
  final VoidCallback onDelete;

  const QuestionAnswerCard({
    super.key,
    required this.questionAnswer,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final subtitle = questionAnswer.selectedValue?.isNotEmpty == true
        ? questionAnswer.selectedValue!
        : (questionAnswer.answer?.isNotEmpty == true
              ? questionAnswer.answer!
              : "No answer");

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface(isDark),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppTheme.cardBorder(isDark), width: 0.5),
        boxShadow: const [AppShadows.cardShadow],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedMessageQuestion,
              size: 22,
              color: AppTheme.secondaryLabelColor(isDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    questionAnswer.questionName ?? "Question",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryOn(isDark),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.secondaryLabelColor(isDark),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              position: PopupMenuPosition.under,
              icon: Icon(
                Icons.more_vert,
                size: 20,
                color: isDark ? Colors.white : Colors.black,
              ),
              onSelected: (value) {
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) {
                return [
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: StatusColors.red),
                        SizedBox(width: 10),
                        Text('Delete', style: TextStyle(color: StatusColors.red)),
                      ],
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}
