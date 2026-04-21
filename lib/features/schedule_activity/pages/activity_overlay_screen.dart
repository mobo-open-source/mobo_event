import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/features/schedule_activity/provider/event_activity_provider.dart';
import 'package:mobo_event/features/schedule_activity/widget/activity_card.dart';
import 'package:mobo_event/shared/helper/helper_method.dart';
import 'package:mobo_event/shared/widgets/shimmer_card/shimmer_card.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';
import '../../home/model/event_short.dart';
import 'add_activity.dart';

class ActivityOverlayScreen extends StatefulWidget {
  final EventShort eventShortDetails;
  const ActivityOverlayScreen({super.key, required this.eventShortDetails});

  @override
  State<ActivityOverlayScreen> createState() => _ActivityOverlayScreenState();
}

class _ActivityOverlayScreenState extends State<ActivityOverlayScreen> {
  @override
  void initState() {
    super.initState();
    _initialLoading();
  }

  _initialLoading() async {
    try {
      if (widget.eventShortDetails.activityIds!.isEmpty) {
        return;
      }

      final activityProvider = Provider.of<EventActivityProvider>(
        context,
        listen: false,
      );

      await activityProvider.fetchActivities(
        widget.eventShortDetails.activityIds!,
      );
    } catch (e) {
      CustomSnackbar.showError(context, cleanedError(e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.eventShortDetails.activityIds?.length ?? 0;

    const int maxVisibleItems = 4;
    const double cardHeight = 80;

    final bool needsScroll = itemCount > maxVisibleItems;

    final double maxListHeight =
        maxVisibleItems * cardHeight + ((maxVisibleItems - 1) * 8);

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: 400,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withAlpha(30),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(16),
                  topLeft: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Activities',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.eventShortDetails.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  if (itemCount > 0)
                    IconButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AddActivityDialog(
                            resId: widget.eventShortDetails.id,
                            model: 'event.event',
                          ),
                        );
                      },
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedAdd01,
                        size: 18,
                        color: primaryColor,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.all(6),
                        minimumSize: const Size(32, 32),
                      ),
                    ),

                  const SizedBox(width: 4),

                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedCancel01,
                      size: 18,
                    ),
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(32, 32),
                    ),
                  ),
                ],
              ),
            ),

            itemCount > 0
                ? Consumer<EventActivityProvider>(
                    builder: (context, provider, child) {
                      if (provider.isLoading) {
                        return ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
                          itemCount:
                              widget.eventShortDetails.activityIds!.length,
                          itemBuilder: (_, __) =>
                              const FullCardShimmer(height: 80, radius: 8),
                        );
                      }

                      return ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: needsScroll
                              ? maxListHeight
                              : double.infinity,
                        ),
                        child: ListView.separated(
                          shrinkWrap: !needsScroll,
                          physics: needsScroll
                              ? const BouncingScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          itemCount: provider.activityList.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 3),
                          itemBuilder: (context, index) {
                            final singleActivity = provider.activityList[index];
                            return ActivityCard(activiy: singleActivity);
                          },
                        ),
                      );
                    },
                  )
                : Flexible(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedCalendar03,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No activities found',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create your first activity',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AddActivityDialog(
                                  resId: widget.eventShortDetails.id,
                                  model: 'event.event',
                                ),
                              );
                            },
                            icon: const HugeIcon(
                              icon: HugeIcons.strokeRoundedAdd01,
                              size: 16,
                            ),
                            label: const Text('Create Activity'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              elevation: 0,
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
