import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/features/event/model/event_detailed_model.dart';
import 'package:mobo_event/features/event/pages/event_edit_screen.dart';
import 'package:mobo_event/features/event/provider/event_detailed_provider.dart';
import 'package:provider/provider.dart';

import '../../../core/const/app_colors.dart';
import '../../../shared/helper/helper_method.dart';
import '../../../shared/widgets/loading/loading_widget.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../../../shared/widgets/widget_card/card_widget.dart';
import '../../home/providers/home_provider.dart';
import '../../home/services/home_services.dart';

class EventMainCard extends StatefulWidget {
  final EventDetailedModel event;
  const EventMainCard({super.key, required this.event});

  @override
  State<EventMainCard> createState() => _EventMainCardState();
}

class _EventMainCardState extends State<EventMainCard> {
  late String kanbanState;

  @override
  void initState() {
    super.initState();
    kanbanState = widget.event.kanbanState.isNotEmpty
        ? widget.event.kanbanState
        : 'normal';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EventEditScreen()),
        );
      },
      child: CardWidget(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    widget.event.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                ),
                _kanbanMenu(),
              ],
            ),

            const SizedBox(height: 8),

            if (widget.event.username != null &&
                widget.event.username!.isNotEmpty)
              _infoRow(HugeIcons.strokeRoundedUser, widget.event.username!),

            if (widget.event.organizerName.isNotEmpty)
              _infoRow(
                HugeIcons.strokeRoundedOffice,
                widget.event.organizerName,
              ),

            _infoRow(
              HugeIcons.strokeRoundedLocation06,
              widget.event.location.isEmpty
                  ? "Online Event"
                  : widget.event.location,
            ),

            const SizedBox(height: 6),

            _timeRow(
              Colors.grey.shade600,
              widget.event.startFullDate,
              widget.event.endFullDate,
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _kanbanMenu() {
    final homeProvider = Provider.of<HomeProvider>(context, listen: false);

    return PopupMenuButton<String>(
      color: Colors.white,
      onSelected: (value) async {
        try {
          loadingDialog(
            context,
            "Changing State",
            "Please wait...",
            LoadingAnimationWidget.fourRotatingDots(
              color: primaryColor,
              size: 30,
            ),
          );

          final services = HomeServices();
          await services.updateKanbanState(
            eventId: widget.event.id,
            newState: value,
          );

          final homeProvider = Provider.of<HomeProvider>(
            context,
            listen: false,
          );
          await homeProvider.gettingStages();
          final provider = Provider.of<EventDetailedProvider>(
            context,
            listen: false,
          );
          provider.reset();
          provider.fetchEventDetails(provider.eventModel!.id);
          hideLoadingDialog(context);

          CustomSnackbar.showSuccess(context, "State changed");
        } catch (_) {
          hideLoadingDialog(context);
          CustomSnackbar.showError(context, "Error while changing state");
        }
      },
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: getKanbanColor(kanbanState).withOpacity(.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          getKanbanIcon(kanbanState),
          color: getKanbanColor(kanbanState),
          size: 18,
        ),
      ),
      itemBuilder: (context) => [
        _kanbanItem("normal", "In Progress"),
        _kanbanItem("done", "Ready"),
        _kanbanItem("blocked", "Blocked"),
        if (homeProvider.version.contains('19'))
          _kanbanItem("cancel", "Cancelled"),
      ],
    );
  }

  Widget _infoRow(List<List<dynamic>> icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          HugeIcon(icon: icon, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeRow(Color color, String text, String end) {
    return Row(
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedCalendar03,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(width: 5),
        Text(
          "Valid until ${end}",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _chip(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "$title: $value",
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  PopupMenuItem<String> _kanbanItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(getKanbanIcon(value), color: getKanbanColor(value), size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
