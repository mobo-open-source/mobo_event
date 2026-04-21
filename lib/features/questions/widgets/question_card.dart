import 'package:flutter/material.dart';
import '../../../core/const/app_colors.dart';
import '../model/event_question.dart';

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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      question.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                  if (onDelete != null)
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      color: Colors.white,
                      icon: const Icon(
                        Icons.more_vert,
                        size: 20,
                        color: Colors.grey,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      onSelected: (value) {
                        if (value == 'delete') onDelete?.call();
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 10),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),

            ],
          ),
        ),
      ),
    );
  }
}
