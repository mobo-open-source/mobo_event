import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/core/services/event_access_rights.dart';
import 'package:mobo_event/features/schedule_activity/model/activities_model.dart';
import 'package:mobo_event/features/schedule_activity/pages/edit_activity.dart';
import 'package:mobo_event/features/schedule_activity/services/event_activity_services.dart';
import 'package:mobo_event/shared/widgets/dialogs/common_dialog.dart';
import 'package:mobo_event/shared/widgets/mobo/mobo_button.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';

import '../../../shared/helper/helper_method.dart';
import '../../../shared/widgets/loading/loading_widget.dart';
import '../../home/providers/home_provider.dart';
import 'actyvityIcon.dart';
import '../../../core/theme/app_theme.dart';

/// Activity list tile — title + status pill, assignee, due date, and a
/// Delete / Mark as Done footer (§5's two-button convention). Tap the card
/// itself to edit; editing was previously its own inline icon here.
class ActivityCard extends StatefulWidget {
  final ActivitiesModel activiy;
  const ActivityCard({super.key, required this.activiy});

  @override
  State<ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<ActivityCard> {
  ActivitiesModel get activiy => widget.activiy;

  /// True while Mark as Done is under way. There is no blocking dialog over the
  /// screen for it: the button spins instead, and this is what stops a second
  /// tap marking the activity done twice (or a Delete cutting across it).
  bool _markingDone = false;

  Future<void> _markAsDone(BuildContext context) async {
    if (_markingDone) return;
    setState(() => _markingDone = true);
    try {
      await EventActivityServices().markAsDone(activiy.id);
      if (!context.mounted) return;
      await Provider.of<HomeProvider>(context, listen: false).gettingStages();
      if (!context.mounted) return;
      CustomSnackbar.showSuccess(context, "Activity Done");
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      setState(() => _markingDone = false);
      CustomSnackbar.showError(context, cleanedError(e.toString()));
    }
  }

  Future<void> _delete(BuildContext context) async {
    if (_markingDone) return;
    final confirm = await CommonDialog.confirm(
      context,
      title: 'Delete Activity',
      message: 'Are you sure you want to delete "${activiy.name}"?',
      confirmText: 'Delete',
    );
    if (confirm != true || !context.mounted) return;

    loadingDialog(
      context,
      "Deleting",
      "Please wait while we delete this activity",
      LoadingAnimationWidget.fourRotatingDots(color: primaryColor, size: 30),
    );
    try {
      await EventActivityServices().removeActivity(activiy.id);
      if (!context.mounted) return;
      await Provider.of<HomeProvider>(context, listen: false).gettingStages();
      if (!context.mounted) return;
      hideLoadingDialog(context);
      CustomSnackbar.showSuccess(context, "Activity deleted");
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      hideLoadingDialog(context);
      CustomSnackbar.showError(context, cleanedError(e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Odoo lets a user change or remove an activity that is theirs, or any
    // activity on an event they can write — see [AccessRights.canChangeActivity].
    final access = context.watch<AccessRights>();
    final assignee = activiy.userId.isNotEmpty && activiy.userId.first is int
        ? activiy.userId.first as int
        : null;
    final canChange = access.canChangeActivity(assigneeId: assignee);
    final canDelete = access.canDeleteActivity(assigneeId: assignee);

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: canChange
          ? () {
              showDialog(
                context: context,
                builder: (context) => EditActivityDialog(activiy: activiy),
              );
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface(isDark),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppTheme.cardBorder(isDark), width: 0.5),
          boxShadow: const [AppShadows.cardShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    activiy.activityType[1]?.toString() ?? '',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOn(isDark),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ActivityIcon(
                  activityType: activiy.activityIcon,
                  activityState: activiy.state,
                  isLabel: true,
                  size: 14,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              activiy.userId.length > 1 ? activiy.userId[1].toString() : '',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.secondaryLabelColor(isDark),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCalendar03,
                  size: 14,
                  color: AppTheme.secondaryLabelColor(isDark),
                ),
                const SizedBox(width: 6),
                Text(
                  activiy.formattedDueDate,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.secondaryLabelColor(isDark),
                  ),
                ),
              ],
            ),
            if (canChange || canDelete) ...[
              const SizedBox(height: 14),
              if (canChange && canDelete)
                MoboButtonRow(
                  secondaryLabel: 'Delete',
                  onSecondary: () => _delete(context),
                  primaryLabel: 'Mark as Done',
                  onPrimary: () => _markAsDone(context),
                  isLoading: _markingDone,
                )
              else if (canChange)
                MoboButton.filled(
                  label: 'Mark as Done',
                  onPressed: () => _markAsDone(context),
                  isLoading: _markingDone,
                )
              else
                MoboButton.outlined(
                  label: 'Delete',
                  onPressed: () => _delete(context),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
