import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/features/schedule_activity/model/activities_model.dart';
import 'package:mobo_event/features/schedule_activity/pages/edit_activity.dart';
import 'package:mobo_event/features/schedule_activity/services/event_activity_services.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/loading/loading_widget.dart';
import '../../home/providers/home_provider.dart';
import '../pages/add_activity.dart';
import 'actyvityIcon.dart';

class ActivityCard extends StatelessWidget {
  final ActivitiesModel activiy;
  const ActivityCard({super.key, required this.activiy});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),

        border: Border.all(color: Colors.grey[200]!, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4, top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 10),
                      Text(
                        activiy.activityType[1]!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        activiy.userId[1],
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                ActivityIcon(
                  activityType: activiy.activityIcon,
                  activityState: activiy.state,
                  isLabel: true,
                  size: 15,
                ),
                SizedBox(width: 20),
              ],
            ),

            SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 10),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedCalendar03,
                    size: 12,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    activiy.formattedDueDate,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      InkWell(
                        onTap: () async {
                          loadingDialog(
                            context,
                            "Mark as Done",
                            "Please wait while we Mark as  Done",
                            LoadingAnimationWidget.fourRotatingDots(
                              color: primaryColor,
                              size: 30,
                            ),
                          );

                          try {
                            final services = EventActivityServices();
                            await services.markAsDone(activiy.id);
                            final homeProvider = Provider.of<HomeProvider>(
                              context,
                              listen: false,
                            );
                            await homeProvider.gettingStages();
                            CustomSnackbar.showSuccess(
                              context,
                              "Activity Done",
                            );

                            hideLoadingDialog(context);
                            Navigator.pop(context);
                          } catch (e) {
                            CustomSnackbar.showError(
                              context,
                              "Error while done activity",
                            );

                            hideLoadingDialog(context);
                          }
                        },
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                          size: 20,
                          color: Colors.green,
                        ),
                      ),
                      SizedBox(width: 10),
                      InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) =>
                                EditActivityDialog(activiy: activiy),
                          );
                        },
                        child: Icon(Icons.edit, size: 20, color: Colors.grey),
                      ),
                      SizedBox(width: 10),
                      InkWell(
                        onTap: () async {
                          loadingDialog(
                            context,
                            "Cancel",
                            "Please wait while we cancelling",
                            LoadingAnimationWidget.fourRotatingDots(
                              color: primaryColor,
                              size: 30,
                            ),
                          );

                          try {
                            final services = EventActivityServices();
                            await services.removeActivity(activiy.id);
                            final homeProvider = Provider.of<HomeProvider>(
                              context,
                              listen: false,
                            );
                            await homeProvider.gettingStages();
                            CustomSnackbar.showSuccess(
                              context,
                              "Activity deleted",
                            );

                            hideLoadingDialog(context);
                            Navigator.pop(context);
                          } catch (e) {
                            CustomSnackbar.showError(
                              context,
                              "Error while deleting activity",
                            );

                            hideLoadingDialog(context);
                          }
                        },
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedDelete02,
                          size: 20,
                          color: Colors.red,
                        ),
                      ),
                      SizedBox(width: 8),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Color getColor(String? kanbanState) {
    if (kanbanState == null) {
      return backgroundColor;
    }
    switch (kanbanState.toLowerCase()) {
      case 'today':
        return Colors.orange;
      case 'planned':
        return Colors.green;
      case 'overdue':
        return Colors.red;
      case 'cancel':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget getIcont(String? iconName, String? iconstate) {
    if (iconName == null || iconName == 'false' || iconstate == null) {
      return const HugeIcon(
        icon: HugeIcons.strokeRoundedClock01,
        color: Colors.grey,
        size: 15,
      );
    }

    final name = iconName.toLowerCase();

    switch (name) {
      case 'fa-check':
        return Icon(Icons.check, size: 15, color: getColor(iconstate));

      case 'fa-phone':
        return Icon(Icons.phone, size: 15, color: getColor(iconstate));

      case 'fa-users':
        return Icon(Icons.people_outline, size: 15, color: getColor(iconstate));

      case 'fa-envelope':
        return Icon(Icons.email, size: 15, color: getColor(iconstate));

      default:
        return HugeIcon(
          icon: HugeIcons.strokeRoundedClock01,
          size: 15,
          color: getColor(iconstate),
        );
    }
  }
}
