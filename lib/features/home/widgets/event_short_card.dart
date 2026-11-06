import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_event/core/services/session_service.dart';
import 'package:mobo_event/core/utils/screen_layout.dart';
import 'package:mobo_event/features/home/model/event_short.dart';
import 'package:mobo_event/features/profile/providers/profile_provider.dart';
import 'package:mobo_event/features/home/services/home_services.dart';
import 'package:mobo_event/features/schedule_activity/pages/activity_overlay_screen.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';

import '../../../shared/helper/helper_method.dart';
import '../../event/pages/event_details_screen.dart';
import '../providers/home_provider.dart';
import '../../../core/theme/app_theme.dart';

class EventShortCard extends StatefulWidget {
  final EventShort eventShortDetails;

  /// Outer inset. Defaults to the Home list's side gutters; the kanban
  /// board passes [EdgeInsets.zero] since its column already spaces cards.
  final EdgeInsetsGeometry padding;

  /// Space around the card itself. Defaults to the Home list's bottom gap;
  /// the kanban board adds side insets too, to sit inside a narrow column.
  final EdgeInsetsGeometry margin;

  /// Width the image column sizes itself against (35% of it). Defaults to
  /// the screen width for the Home list. The kanban board passes its own
  /// known column width explicitly — it can't be measured with a
  /// LayoutBuilder here, since drag_and_drop_lists wraps each column in an
  /// IntrinsicHeight, and Flutter refuses intrinsic sizing through one.
  final double? width;

  const EventShortCard({
    super.key,
    required this.eventShortDetails,
    this.padding = const EdgeInsets.only(left: 15, right: 15),
    this.margin = const EdgeInsets.only(bottom: 10),
    this.width,
  });

  @override
  State<EventShortCard> createState() => _EventShortCardState();
}

class _EventShortCardState extends State<EventShortCard> {
  /// Widest the image column gets in the Home list on a phone in landscape —
  /// what 35% of a 360dp-wide portrait phone is.
  static const double _landscapeImageColumnMax = 126;

  /// The height of each thing in the card's bottom row — activity icon,
  /// responsible user's photo, status badge — so their tops and bottoms line up
  /// instead of three different heights sharing one centre line. 24 is the
  /// status badge's own height with its ⌄.
  static const double _footerHeight = 24;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // The responsible user's photo is captured when the list loads. For your
    // own events it comes live from the profile instead, so a photo you have
    // just changed shows here too rather than the one from before the edit.
    final myAvatar = context.select<ProfileProvider, Uint8List?>(
      (profile) => profile.userAvatar,
    );
    final currentUserId = SessionService.instance.currentSession?.userId;
    final isMine =
        currentUserId != null &&
        widget.eventShortDetails.userId == currentUserId;
    final responsibleImage = isMine && myAvatar != null
        ? myAvatar
        : widget.eventShortDetails.image;

    // The image column is a fraction of this width. Defaults to the screen
    // width for the Home list; the kanban board passes its own column width.
    final cardWidth = widget.width ?? MediaQuery.of(context).size.width;

    // In the Home list on a phone in landscape the screen is 700–900dp wide, so
    // 35% of it made the image column ~300dp for a card only 170 tall — a huge,
    // stretched picture — and the card itself ran the full width. There the
    // image column stops at what it is on a typical portrait phone, and the
    // card is capped and centred. Portrait and the kanban (which passes its own
    // column width) are untouched.
    final wideList = widget.width == null && context.isLandscape;
    final imageColumnWidth = wideList
        ? math.min(cardWidth * 0.35, _landscapeImageColumnMax)
        : cardWidth * 0.35;

    final card = Padding(
      padding: widget.padding,
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
            boxShadow: [AppShadows.cardShadow],
          ),
          child: Row(
            children: [
              Container(
                width: imageColumnWidth,
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
                  // No left padding: the image column's own 15px on its right
                  // is the whole gap between picture and text (it was 15 + 14).
                  // 15 at the bottom, the picture's own inset, so the bottom
                  // row (activity icon, photo, status) ends level with the
                  // bottom of the picture instead of 7px below it.
                  // The top is 16, a little past the picture's 15: measured on
                  // a device, the heading's capitals sat ~3px above the
                  // picture's top edge at 13 (the font's own space above its
                  // letters is smaller than its metrics suggest), so 16 puts
                  // them level with it.
                  padding: const EdgeInsets.fromLTRB(0, 16, 14, 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.eventShortDetails.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                          // The natural line height (~22) leaves ~5px of empty
                          // space above the letters, which made them impossible
                          // to line up with the picture's top edge by padding.
                          height: 1,
                        ),
                      ),
                      // 9 (was 8) because the tighter heading line above is
                      // ~6px shorter. The rows below move down with the
                      // heading; the Spacer above the footer takes up the
                      // difference, so the footer itself stays put.
                      const SizedBox(height: 9),

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
                          Flexible(
                            child: Text(
                              "${widget.eventShortDetails.attended} People",
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
                          // Calendar03, the glyph the activity icon below (and
                          // the rest of the app) uses for a calendar.
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedCalendar03,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              "${widget.eventShortDetails.start.day} ${widget.eventShortDetails.monthShort}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
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
                            // The icon (20) keeps its size, centred in a slot as
                            // tall as the photo and the badge, and flush left
                            // with the rows above.
                            child: SizedBox(
                              height: _footerHeight,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: getIcont(
                                  widget.eventShortDetails.activityTypeIcon,
                                  widget.eventShortDetails.activityState,
                                ),
                              ),
                            ),
                          ),

                          const Spacer(),

                          // As tall as the status badge, so the two share a top
                          // and a bottom edge.
                          Container(
                            height: _footerHeight,
                            width: _footerHeight,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: _memoryImageOrAsset(
                                responsibleImage,
                                'assets/profile.jpg',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          // The status, last in the bottom row, after the
                          // responsible user's photo. Held to the row's height
                          // whether or not it carries the ⌄.
                          SizedBox(
                            height: _footerHeight,
                            child: _statusMenu(homeProvider, isDark),
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

    return wideList ? ConstrainedContent(child: card) : card;
  }

  /// The status badge, for the heading row. With the right to move the event
  /// it is also the menu that changes the status, and wears a ⌄ to say so;
  /// without it, it is only a label.
  Widget _statusMenu(HomeProvider homeProvider, bool isDark) {
    // Changing the status is a write on the event; an account that can't make
    // one sees the status but can't open the menu.
    if (!homeProvider.access.canMoveEvent) {
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
          final services = HomeServices();
          await services.updateKanbanState(
            eventId: widget.eventShortDetails.id,
            newState: value,
          );

          await homeProvider.gettingStages();

          CustomSnackbar.showSuccess(context, "State changed");
        } catch (_) {
          CustomSnackbar.showError(
            context,
            "Error occurred while changing state",
          );
        }
      },
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(AppRadius.badge),
      // `child`, not `icon`: an icon makes an IconButton with Material's 48px
      // min tap target, which would stretch the heading row this sits in (and
      // overflow the card's fixed height).
      //
      // The same status badge Details shows (§10), not a bare coloured dot —
      // with a ⌄, so it reads as the menu it is rather than a label.
      child: StatusColors.buildStatusBadge(
        context,
        getKanbanLabel(kanbanState),
        color: getKanbanColor(kanbanState),
        dropdown: true,
      ),
      itemBuilder: (context) {
        return [
          _kanbanItem("normal", "In Progress"),
          _kanbanItem("done", "Ready for Next Stage"),
          _kanbanItem("blocked", "Blocked"),
          if (homeProvider.compat.hasCancelledKanbanState)
            _kanbanItem("cancel", "Cancelled"),
        ];
      },
    );
  }

  /// kanban menu
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
