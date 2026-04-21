import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/features/questions/widgets/edit_question.dart';
import 'package:provider/provider.dart';
import '../../home/providers/home_provider.dart';
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

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(color: primaryColor.withAlpha(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    "Question Details",
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const Spacer(),

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
                    icon: const Icon(Icons.edit, size: 25, color: primaryColor),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(32, 32),
                    ),
                  ),

                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "Title ",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    question.displayName,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 14),

                SizedBox(height: 10),
                Row(
                  children: [
                    const Text(
                      "Question Type ",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    getTypeLabel(),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 10),

                if (question.isMandatoryAnswer)
                  _buildFlagRow("Mandatory", question.isMandatoryAnswer),

                if (question.oncePerOrder)
                  _buildFlagRow("Ask once per order", question.oncePerOrder),

                if (homeProvider.version.contains('19') && question.isDefault)
                  _buildFlagRow("Default Question", question.isDefault),
                if (homeProvider.version.contains('19') && question.isReusable)
                  _buildFlagRow("Is reusable?", question.isReusable),
                const SizedBox(height: 5),
                if (question.answers.isNotEmpty &&
                    question.questionType == "simple_choice") ...[
                  const Text(
                    "Options",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),

                  ...question.answers.map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 6,
                            color: Colors.black,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(e.name, style: TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlagRow(String label, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          IgnorePointer(
            ignoring: value,
            child: Checkbox(
              value: value,
              onChanged: (_) {},
              fillColor: WidgetStatePropertyAll(
                value ? primaryColor : Colors.white,
              ),
              checkColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
