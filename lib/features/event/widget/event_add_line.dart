import 'package:flutter/material.dart';
import 'package:mobo_event/features/documentation/pages/documentation_screen.dart';
import 'package:mobo_event/features/event/widget/option_widget.dart';
import 'package:mobo_event/features/event/widget/ticket_line_widget.dart';
import 'package:mobo_event/features/questions/pages/event_question_page.dart';
import 'package:mobo_event/features/scheduler/page/mail_scheduler_screen.dart';
import 'package:mobo_event/shared/widgets/widget_card/card_widget.dart';

class EventAddLine extends StatefulWidget {
  final int eventId;
  const EventAddLine({super.key, required this.eventId});

  @override
  State<EventAddLine> createState() => _EventAddLineState();
}

class _EventAddLineState extends State<EventAddLine> {
  List<String> options = [
    "Tickets",
    "Communication",
    "Questions",
    "Notes&documents",
  ];

  int selectedIndex = 0;
  @override
  Widget build(BuildContext context) {
    List<Widget> containers = [
      TicketLineWidget(eventId: widget.eventId),
      MailScheduler(eventId: widget.eventId),
      EventQuestionPage(eventId: widget.eventId),
      DocumentationScreen(),
    ];

    return Column(
      children: [
        SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return OptionWidget(
                  title: options[index],
                  isActive: selectedIndex == index,
                  onTap: () {
                    setState(() {
                      selectedIndex = index;
                    });
                  },
                );
              },
            ),
          ),
        ),
        SizedBox(height: 10),
        CardWidget(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.47,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 10),
                Expanded(child: containers[selectedIndex]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
