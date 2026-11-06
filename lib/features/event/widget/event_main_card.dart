import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_event/features/event/model/event_detailed_model.dart';
import 'package:mobo_event/features/event/provider/event_detailed_provider.dart';
import 'package:provider/provider.dart';

import '../../../core/const/app_colors.dart';
import '../../../core/services/event_access_rights.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/helper/helper_method.dart';
import '../../../shared/widgets/loading/loading_widget.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../../../shared/widgets/widget_card/card_widget.dart';
import '../../home/providers/home_provider.dart';
import '../../home/services/home_services.dart';
import 'event_publish_row.dart';

class EventMainCard extends StatefulWidget {
  final EventDetailedModel event;
  const EventMainCard({super.key, required this.event});

  @override
  State<EventMainCard> createState() => _EventMainCardState();
}

class _EventMainCardState extends State<EventMainCard> {
  /// The title's size and line height. The line height is explicit so the
  /// height of its first line is known: the status badge is centred on it.
  static const double _titleSize = 20;
  static const double _titleLineHeight = 1.3;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Height of the title's first line at the user's text size.
    final titleLine =
        MediaQuery.textScalerOf(context).scale(_titleSize) * _titleLineHeight;
    // Editing opens from the Details app bar, not from tapping this card.
    return CardWidget(
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
                    fontSize: _titleSize,
                    height: _titleLineHeight,
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Level with the title's first line, whether the title takes one
              // line or two — not with the middle of the whole title, nor
              // dropped below its top by a tap-target's padding.
              SizedBox(
                height: titleLine,
                child: Center(widthFactor: 1, child: _kanbanMenu()),
              ),
            ],
          ),

          const SizedBox(height: 8),

          if (widget.event.username != null &&
              widget.event.username!.isNotEmpty)
            _infoRow(HugeIcons.strokeRoundedUser, widget.event.username!),

          if (widget.event.organizerName.isNotEmpty)
            _infoRow(HugeIcons.strokeRoundedOffice, widget.event.organizerName),

          _infoRow(
            HugeIcons.strokeRoundedLocation06,
            widget.event.location.isEmpty
                ? "Online Event"
                : widget.event.location,
          ),

          const SizedBox(height: 6),

          _timeRow(
            AppTheme.secondaryLabelColor(isDark),
            widget.event.startFullDate,
            widget.event.endFullDate,
          ),

          // Whether the event is live on the website. Skipped on a server
          // without website_event, which has no such state.
          if (widget.event.hasPublishState) ...[
            const SizedBox(height: 8),
            EventPublishRow(event: widget.event),
          ],
          SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _kanbanMenu() {
    final homeProvider = Provider.of<HomeProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // The status badge is a menu for changing the status — a write on the
    // event. Without that right it is only a badge.
    if (!context.watch<AccessRights>().canMoveEvent) {
      return StatusColors.buildStatusBadge(
        context,
        getKanbanLabel(kanbanState),
        color: getKanbanColor(kanbanState),
      );
    }

    return PopupMenuButton<String>(
      color: isDark ? AppTheme.darkPopupSurface : Colors.white,
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
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(AppRadius.badge),
      // `child`, not `icon`: an icon makes an IconButton, which keeps
      // Material's 48px min tap target and centres the badge inside it,
      // dropping it well below the title's first line.
      child: StatusColors.buildStatusBadge(
        context,
        getKanbanLabel(kanbanState),
        color: getKanbanColor(kanbanState),
      ),
      itemBuilder: (context) => [
        _kanbanItem("normal", "In Progress"),
        _kanbanItem("done", "Ready"),
        _kanbanItem("blocked", "Blocked"),
        if (homeProvider.compat.hasCancelledKanbanState)
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
    final style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: color,
    );
    return Row(
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedCalendar03,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 5),
        // Both dates stay on one line when they fit; in a narrow card (the
        // landscape side pane) the second one wraps under the first instead
        // of running off the edge.
        Expanded(
          child: Wrap(
            spacing: 5,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(text, style: style),
              Text("Valid until ${end}", style: style),
            ],
          ),
        ),
      ],
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
