import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../model/event_question.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/section_list_state.dart';

class QuestionCard extends StatelessWidget {
  final EventQuestion question;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const QuestionCard({
    super.key,
    required this.question,
    this.onTap,
    this.onDelete,
  });

  String getTypeLabel() {
    switch (question.questionType.toLowerCase()) {
      case 'simple_choice':
        return "Single Selection";
      case 'multiple_choice':
        return "Multiple Choice";
      case 'email':
        return "Email";
      case 'name':
        return "Name";
      case 'text_box':
        return "Text Box";
      case 'phone':
        return "Phone";
      default:
        return question.questionType;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // The bordered, shadow-less row the Tickets, Communication and Questions
    // lists share (see [SectionCard]).
    return SectionCard(
      onTap: onTap,
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
                  question.title,
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
                  getTypeLabel(),
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
          if (onDelete != null) SectionDeleteButton(onPressed: onDelete!),
        ],
      ),
    );
  }
}
