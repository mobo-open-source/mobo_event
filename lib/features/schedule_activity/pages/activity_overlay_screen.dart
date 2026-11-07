import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/core/services/event_access_rights.dart';
import 'package:mobo_event/features/schedule_activity/provider/event_activity_provider.dart';
import 'package:mobo_event/features/schedule_activity/widget/activity_card.dart';
import 'package:mobo_event/shared/helper/helper_method.dart';
import 'package:mobo_event/shared/widgets/shimmer_card/shimmer_card.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';
import '../../home/model/event_short.dart';
import 'add_activity.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_layout.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemCount = widget.eventShortDetails.activityIds?.length ?? 0;
    // A phone in landscape is only ~300-400dp tall: a 70%-of-height cap would
    // leave the cards a sliver. Short windows get the whole height (the
    // dialog's own inset keeps it on screen) and a tighter header.
    final compact = context.isShortScreen;

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.white,
      insetPadding: compact
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
          : const EdgeInsets.all(16),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: compact
              ? double.infinity
              : MediaQuery.of(context).size.height * 0.7,
          maxWidth: 400,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [AppShadows.panelShadow(isDark)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: compact
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 4)
                  : const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Activities',
                          style: TextStyle(
                            color: AppTheme.textPrimaryOn(isDark),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.eventShortDetails.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryLabelColor(isDark),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Scheduling needs create on the activity and write on the
                  // event it is scheduled for.
                  if (itemCount > 0 &&
                      context.watch<AccessRights>().canScheduleActivity)
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
                        size: 20,
                        color: primaryColor,
                      ),
                      style: IconButton.styleFrom(
                        // A light grey disc, so the button still reads as
                        // one on the plain header.
                        backgroundColor: isDark
                            ? Colors.grey[800]
                            : AppTheme.fieldFill,
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(40, 40),
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
                ? Flexible(
                    child: Consumer<EventActivityProvider>(
                      builder: (context, provider, child) {
                        if (provider.isLoading) {
                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            shrinkWrap: true,
                            itemCount:
                                widget.eventShortDetails.activityIds!.length,
                            itemBuilder: (_, _) =>
                                const FullCardShimmer(height: 80, radius: 8),
                          );
                        }

                        // Each card now carries a Delete/Mark as Done
                        // footer, so it's much taller than the old
                        // icon-row design this dialog was originally sized
                        // for — always scrollable, no guessed per-item
                        // height, rather than only scrolling past a fixed
                        // count and clipping otherwise. shrinkWrap sizes the
                        // dialog to the cards themselves (one activity =
                        // one card tall, not a stretched-out sheet) while
                        // still scrolling once there are enough to fill it.
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          shrinkWrap: true,
                          itemCount: provider.activityList.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 3),
                          itemBuilder: (context, index) {
                            final singleActivity = provider.activityList[index];
                            return ActivityCard(activiy: singleActivity);
                          },
                        );
                      },
                    ),
                  )
                : Flexible(
                    // Scrolls only when the empty state is taller than the
                    // dialog (a short landscape window), so it is never cut.
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(compact ? 12 : 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedCalendar03,
                            size: 48,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No activities found',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.secondaryLabelColor(isDark),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          // Scheduling is offered only to an account that may create
                          // an activity and write the event it is for.
                          if (context
                              .watch<AccessRights>()
                              .canScheduleActivity) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Create your first activity',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // §5's primary button: 48 tall, radius 12, 16/bold.
                            SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
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
                                  size: 20,
                                ),
                                label: const Text('Create Activity'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  elevation: 0,
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
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
}
