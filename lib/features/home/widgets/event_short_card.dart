import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/features/home/model/event_short.dart';
import 'package:mobo_event/features/home/services/home_services.dart';
import 'package:mobo_event/features/schedule_activity/pages/activity_overlay_screen.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';

import '../../../shared/helper/helper_method.dart';
import '../../../shared/widgets/loading/loading_widget.dart';
import '../../event/pages/event_details_screen.dart';
import '../providers/home_provider.dart';

class EventShortCard extends StatefulWidget {
  final EventShort eventShortDetails;
  const EventShortCard({super.key, required this.eventShortDetails});

  @override
  State<EventShortCard> createState() => _EventShortCardState();
}

class _EventShortCardState extends State<EventShortCard> {
  late String kanbanState;

  @override
  void initState() {
    super.initState();
    kanbanState = widget.eventShortDetails.kanbanState.isNotEmpty
        ? widget.eventShortDetails.kanbanState
        : 'normal';
  }

  Widget _memoryImageOrAsset(
    Uint8List? bytes,
    String assetPath, {
    BoxFit fit = BoxFit.cover,
  }) {
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        fit: fit,
        errorBuilder: (_, __, ___) => Image.asset(assetPath, fit: fit),
      );
    }
    return Image.asset(assetPath, fit: fit);
  }

  @override
  Widget build(BuildContext context) {
    final homeProvider = Provider.of<HomeProvider>(context, listen: false);
    final cardWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.only(left: 15, right: 15),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  EventDetailsScreen(id: widget.eventShortDetails.id),
            ),
          );
        },
        child: Container(
          height: 170,
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(4, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(-4, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: cardWidth * 0.35,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(12),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: Colors.grey,
                      height: double.infinity,
                      width: double.infinity,
                      child: _memoryImageOrAsset(
                        widget.eventShortDetails.eventImage,
                        'assets/event_image.jpg',
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.eventShortDetails.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedLocation06,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.eventShortDetails.location.isEmpty
                                  ? "Online Event"
                                  : widget.eventShortDetails.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      Row(
                        children: [
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedUserMultiple02,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "${widget.eventShortDetails.attended} People",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      Row(
                        children: [
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedCalendar02,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "${widget.eventShortDetails.start.day} ${widget.eventShortDetails.monthShort}",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),

                      const Spacer(),

                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => ActivityOverlayScreen(
                                  eventShortDetails: widget.eventShortDetails,
                                ),
                              );
                            },
                            child: getIcont(
                              widget.eventShortDetails.activityTypeIcon,
                              widget.eventShortDetails.activityState.toString(),
                            ),
                          ),

                          const Spacer(),

                          Container(
                            height: 35,
                            width: 35,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: _memoryImageOrAsset(
                                widget.eventShortDetails.image,
                                'assets/profile.jpg',
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          PopupMenuButton<String>(
                            color: Colors.white,
                            onSelected: (value) async {
                              try {
                                final services = HomeServices();
                                await services.updateKanbanState(
                                  eventId: widget.eventShortDetails.id,
                                  newState: value,
                                );

                                await homeProvider.gettingStages();

                                CustomSnackbar.showSuccess(
                                  context,
                                  "State changed",
                                );
                              } catch (e) {
                                CustomSnackbar.showError(
                                  context,
                                  "Error occurred while changing state",
                                );
                              }
                            },
                            icon: SizedBox(
                              height: 18,
                              width: 18,
                              child: Icon(
                                getKanbanIcon(kanbanState),
                                color: getKanbanColor(kanbanState),
                                size: 18,
                              ),
                            ),
                            itemBuilder: (context) {
                              return [
                                _kanbanItem("normal", "In Progress"),
                                _kanbanItem("done", "Ready for Next Stage"),
                                _kanbanItem("blocked", "Blocked"),
                                if (homeProvider.version.contains('19'))
                                  _kanbanItem("cancel", "Cancelled"),
                              ];
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: getKanbanColor(value),
                fontWeight: kanbanState == value
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
          if (kanbanState == value) const Icon(Icons.check, size: 16),
        ],
      ),
    );
  }
}
