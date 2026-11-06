import 'dart:async';
import 'dart:typed_data';

import 'package:drag_and_drop_lists/drag_and_drop_lists.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/models/event_stage.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_layout.dart';
import '../../../shared/helper/helper_method.dart';
import '../../../shared/widgets/dialogs/common_dialog.dart';
import '../../../shared/widgets/dialogs/pinned_footer_layout.dart';
import '../../../shared/widgets/forms/mobo_form_field.dart';
import '../../../shared/widgets/mobo/mobo_button.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../../event/pages/event_details_screen.dart';
import '../../profile/providers/profile_provider.dart';
import '../../schedule_activity/pages/activity_overlay_screen.dart';
import '../model/event_group.dart';
import '../model/event_short.dart';
import '../providers/home_provider.dart';
import 'no_events_empty_state.dart';

/// Kanban board for the Home screen (CLAUDE.md §11): one column per event
/// stage, cards draggable both within and across columns. Dragging a card
/// into another column writes that event's `stage_id`; dragging a column
/// reorders stages. "Add Stage" sits as the board's own trailing target
/// (§11's "Add stage" affordance) rather than a real column, so it doesn't
/// inherit the column shell's stretched, empty body.
///
/// With a Group By applied (the filter sheet's Group By tab) the columns are
/// that grouping's groups instead — one per group that has an event, as in
/// Odoo's grouped kanban. Dropping a card on one writes the field the grouping
/// is on (the responsible, the template, the venue); a month isn't a record, so
/// those cards stay put. The stage management — rename, delete, reorder, Add
/// Stage — belongs to the stage board and isn't offered there.
class KanbanBoard extends StatefulWidget {
  final HomeProvider provider;
  final VoidCallback? onClearFilters;

  /// Landscape: the board has far less height to work with and nothing
  /// floats over its bottom edge (the Home screen moves its action buttons
  /// to a side rail), so the reserved bottom gap shrinks and each column
  /// gets every pixel it can.
  final bool compact;

  const KanbanBoard({
    super.key,
    required this.provider,
    this.onClearFilters,
    this.compact = false,
  });

  static const double _listWidth = 300;
  static const EdgeInsets _listPadding = EdgeInsets.symmetric(
    horizontal: 6,
    vertical: 4,
  );
  /// Horizontal inset matches the column header's, so a card's edges line up
  /// with the stage pill above it.
  static const EdgeInsets _cardMargin = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 6,
  );

  @override
  State<KanbanBoard> createState() => _KanbanBoardState();
}

class _KanbanBoardState extends State<KanbanBoard> {
  HomeProvider get provider => widget.provider;

  /// Our own horizontal [ScrollController], nudged on a timer while a card is
  /// held near either edge, stopped as soon as the drag ends or leaves the
  /// edge zone.
  ///
  /// Cards are dragged with our own Draggable (see the note below), which the
  /// package's built-in auto-scroll-while-dragging has no way to see — that
  /// only fires for drags it starts itself.
  final ScrollController _hScrollController = ScrollController();
  Timer? _autoScrollTimer;
  double? _autoScrollDirection;

  static const double _edgeZone = 60;
  static const double _scrollStep = 14;

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _hScrollController.dispose();
    super.dispose();
  }

  void _onCardDragUpdate(DragUpdateDetails details) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dx = details.globalPosition.dx;
    if (dx < _edgeZone) {
      _startAutoScroll(-1);
    } else if (dx > screenWidth - _edgeZone) {
      _startAutoScroll(1);
    } else {
      _stopAutoScroll();
    }
  }

  void _startAutoScroll(double direction) {
    if (_autoScrollDirection == direction) return;
    _autoScrollDirection = direction;
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_hScrollController.hasClients) return;
      final position = _hScrollController.position;
      final next = (position.pixels + direction * _scrollStep).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      _hScrollController.jumpTo(next);
    });
  }

  void _stopAutoScroll() {
    _autoScrollDirection = null;
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupBy = provider.groupBy;
    // Grouped by stage is just the stage board; any other grouping replaces the
    // stage columns with its own.
    final grouped = groupBy != null && groupBy != EventGroupBy.stage;
    final allStages = [...provider.stageList]
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    // A search/filter narrows `eventList` but previously still drew every
    // stage column, including ones left with zero matching events (each
    // just showing "No event in this stage") plus the "Add Stage" target —
    // noise when the user is looking at filtered results, not managing
    // stages. While a query is active, only stages that still have a
    // matching event stay on the board.
    final isFiltered =
        provider.activeFilters.isNotEmpty || provider.searchText.isNotEmpty;
    final stages = isFiltered
        ? allStages
              .where(
                (stage) => provider.eventList.any((e) => e.stageId == stage.id),
              )
              .toList()
        : allStages;

    final columns = grouped
        ? [for (final group in provider.groupedEvents) _ColumnSpec.group(group)]
        : [
            for (final stage in stages)
              _ColumnSpec.stage(
                stage,
                provider.eventList.where((e) => e.stageId == stage.id).toList(),
              ),
          ];

    // No column has a matching event at all — the same "no events" state the
    // List view shows for an empty filtered result, not an empty board.
    if ((isFiltered || grouped) && columns.isEmpty) {
      return Center(
        child: NoEventsEmptyState(
          showClearFilters: isFiltered || grouped,
          onClearFilters: widget.onClearFilters,
        ),
      );
    }

    // drag_and_drop_lists hard-codes NeverScrollableScrollPhysics on every
    // column's own card list — it can't scroll a column independently. So
    // each column is really just ONE item here: a fixed-height widget we
    // built ourselves (header + a genuinely scrollable card list, with our
    // own Draggable/DragTarget for moving cards between columns), sized to
    // the space this LayoutBuilder measures. The package is only used for
    // the horizontal column layout — columns themselves aren't draggable
    // (see _column: without a dedicated handle, the package puts a plain,
    // non-long-press Draggable over the *whole* column, which hijacked every
    // vertical drag, including a plain attempt to scroll a column, before it
    // ever reached our own card drag or the column's own list. A dedicated
    // handle (see listDragHandle below) fixes that: only touches on the
    // handle itself start a column drag, so it can't compete with card
    // drags or with scrolling the column underneath it.
    return LayoutBuilder(
      builder: (context, constraints) {
        final board = DragAndDropLists(
          axis: Axis.horizontal,
          scrollController: _hScrollController,
          listWidth: KanbanBoard._listWidth,
          listPadding: KanbanBoard._listPadding,
          lastItemTargetHeight: 0,
          // No visible handle icon — the header itself is the drag handle.
          // Sized to the header's height and most of its width, but not
          // the far right, so the "⋮" menu sitting there stays tappable
          // instead of being covered by this (invisible) drag region.
          listDragHandle: DragHandle(
            // Default is onLeft: false, which pins this to the column's
            // RIGHT edge — directly on top of the "⋮" menu, not clear of
            // it. That's what made the menu only sometimes open: it was
            // racing this handle's immediate (non-long-press) Draggable
            // for the same touch.
            onLeft: true,
            verticalAlignment: DragHandleVerticalAlignment.top,
            child: const SizedBox(
              width: KanbanBoard._listWidth - 60,
              height: 48,
            ),
          ),
          onListReorder: (oldListIndex, newListIndex) {
            // `stages` is only the filtered subset while a query is active,
            // so its indices don't line up with the real stage order —
            // reordering columns is disabled while filtered (see `canDrag`
            // in `_column`), but guard here too in case the package still
            // reports a drag. Groups have no order to change.
            if (isFiltered || grouped) return;
            provider
                .reorderStages(stages, oldListIndex, newListIndex)
                .catchError((e) {
                  if (context.mounted) {
                    CustomSnackbar.showError(
                      context,
                      "Couldn't reorder stages",
                    );
                  }
                });
          },
          // Cards move between columns via our own DragTarget below, not
          // through the package's item reordering.
          onItemReorder: (_, _, _, _) {},
          // The board's own trailing target — always the last thing in the
          // row, scrolls with the columns, and (unlike a DragAndDropList)
          // has no painted background of its own, so it reads as a plain
          // floating button rather than an empty card. Hidden while a
          // search/filter is active — adding a stage doesn't belong in a
          // filtered results view — and for anyone the server won't let create
          // stages (Odoo grants that to Event administrators only).
          // §11's "Add stage" affordance: the same white, 16px-rounded
          // column shell as a real column, sized to its own content rather
          // than the board's full height, holding the button.
          listTarget: isFiltered || grouped || !provider.access.canAddStage
              ? null
              : SizedBox(
                  width:
                      KanbanBoard._listWidth -
                      KanbanBoard._listPadding.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: _AddStageButton(provider: provider),
                    ),
                  ),
                ),
          children: [
            for (final column in columns)
              _column(
                context,
                isDark,
                column,
                constraints.maxHeight,
                _onCardDragUpdate,
                _stopAutoScroll,
                canDrag:
                    !isFiltered &&
                    !grouped &&
                    provider.access.canReorderStages,
              ),
          ], // maxHeight is a cap, not a fixed size — see _column.
        );

        if (!isFiltered && !grouped) return board;

        // Filtered (or grouped) down to a handful of columns, with no "Add
        // Stage" target after them: left-anchored in the full board width just
        // reads as a mostly-empty screen, so centre the narrower content
        // instead — only while it actually fits without needing to scroll.
        final contentWidth =
            columns.length *
            (KanbanBoard._listWidth + KanbanBoard._listPadding.horizontal);
        if (contentWidth >= constraints.maxWidth) return board;

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: contentWidth, child: board),
        );
      },
    );
  }

  /// Header + a fitted card's own height (card + its margin), used to size a
  /// column to how many events it actually has instead of always taking the
  /// full board height.
  ///
  /// A bit taller than the card's own measured height, and with an extra
  /// bottom buffer below — a tight, knife-edge fit is how a single card ends
  /// up clipped by a few px if its text wraps a little taller than estimated.
  static const double _headerHeight = 48;
  static const double _fittedCardHeight = 150;
  static const double _bottomBuffer = 20;

  /// A column that grows all the way to `maxHeight` sits flush against the
  /// very edge of the space it's given, so its rounded bottom corner and
  /// shadow have no visible margin below them to read against — worse, that
  /// edge lands right under the floating QR button.
  ///
  /// Capping a bit short of `maxHeight` keeps a clean gap there always visible.
  static const double _bottomSafeMargin = 20;

  /// Landscape has no floating button under the board, so only enough gap for
  /// the column's rounded corner and shadow to read.
  static const double _compactBottomSafeMargin = 8;

  DragAndDropList _column(
    BuildContext context,
    bool isDark,
    _ColumnSpec column,
    double maxHeight,
    ValueChanged<DragUpdateDetails> onCardDragUpdate,
    VoidCallback onCardDragEnd, {
    required bool canDrag,
  }) {
    final events = column.events;

    // Empty and single-card columns read oddly short — and give a dropped
    // card less room to land in — if left to shrink all the way to the
    // header, so an empty column still gets one card's worth of height
    // instead of stretching to the full board (kept compact, not
    // Expanded, so "No event in this stage" doesn't float in a huge box).
    //
    // The empty-column drop target not accepting a drag wasn't actually a
    // height problem — the drop zone's *width* was collapsing to zero
    // (see the SizedBox.expand() note below); this compact height doesn't
    // reopen that.
    final contentHeight =
        _headerHeight +
        _bottomBuffer +
        (events.length * _fittedCardHeight).clamp(
          _fittedCardHeight,
          double.infinity,
        );
    final effectiveMaxHeight =
        maxHeight -
        (widget.compact ? _compactBottomSafeMargin : _bottomSafeMargin);
    final fittingHeight = contentHeight < effectiveMaxHeight
        ? contentHeight
        : effectiveMaxHeight;
    // Never shorter than the header: a negative or sub-header height (a very
    // short board — keyboard open) would overflow the column's own header.
    final columnHeight = fittingHeight < _headerHeight
        ? _headerHeight
        : fittingHeight;

    return DragAndDropList(
      // Draggable, but only via the header's handle icon (listDragHandle on
      // KanbanBoard.build) — never by touching the column body, which would
      // fight with card drags and with scrolling. Disabled entirely while
      // filtered, since `stages` is then only a subset and reordering it
      // wouldn't correspond to the real stage sequence.
      canDrag: canDrag,
      children: [
        DragAndDropItem(
          canDrag: false,
          child: SizedBox(
            height: columnHeight,
            child: _ColumnContent(
              isDark: isDark,
              column: column,
              provider: provider,
              onCardDragUpdate: onCardDragUpdate,
              onCardDragEnd: onCardDragEnd,
            ),
          ),
        ),
      ],
    );
  }
}

/// What a board column shows: one stage, or one group of a grouped board.
class _ColumnSpec {
  final String title;
  final List<EventShort> events;
  final EventStage? stage;
  final EventGroup? group;

  _ColumnSpec.stage(EventStage this.stage, this.events)
    : title = stage.name,
      group = null;

  _ColumnSpec.group(EventGroup this.group)
    : title = group.label,
      events = group.events,
      stage = null;

  /// Whether [event] may be dropped here: not on the column it is already in,
  /// and on a grouped board only where the groups are records.
  bool accepts(EventShort event, HomeProvider provider) {
    final stage = this.stage;
    if (stage != null) return event.stageId != stage.id;
    return (provider.groupBy?.isDraggable ?? false) &&
        !events.any((e) => e.id == event.id);
  }

  /// Writes the move: the stage, or the field the grouping is on.
  Future<void> drop(EventShort event, HomeProvider provider) {
    final stage = this.stage;
    return stage != null
        ? provider.moveEventToStage(event.id, stage.id)
        : provider.moveEventToGroup(event.id, group!);
  }
}

/// One column's full contents: header + its own scrollable card list —
/// built by hand (see [KanbanBoard.build]) so it can actually scroll on its
/// own instead of inheriting the package's fixed, non-scrolling body.
class _ColumnContent extends StatelessWidget {
  final bool isDark;
  final _ColumnSpec column;
  final HomeProvider provider;
  final ValueChanged<DragUpdateDetails> onCardDragUpdate;
  final VoidCallback onCardDragEnd;

  const _ColumnContent({
    required this.isDark,
    required this.column,
    required this.provider,
    required this.onCardDragUpdate,
    required this.onCardDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final stage = column.stage;
    final events = column.events;
    // Cards of a stage board always move (stage_id); on a grouped board only
    // where the groups are records that can be written.
    final cardsMove =
        provider.access.canMoveEvent &&
        (stage != null || (provider.groupBy?.isDraggable ?? false));

    // White column, white cards, no border — the column reads by its
    // rounded shape and shadow, not an outline; without it, a white column
    // on the page's own white background has no visible edge at all. Two
    // layered, low-opacity shadows (a tight one close to the edge, a wider
    // one further out) read as one soft, blended glow instead of a single
    // BoxShadow's harder, more defined band. The shadow has to live on an
    // unclipped outer Container — putting it on the same decoration as a
    // `clipBehavior` would clip the shadow itself away, since the clip and
    // the decoration paint together.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.22)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.16)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          children: [
            _ColumnHeader(
              isDark: isDark,
              title: column.title,
              count: events.length,
              // Stage management is the stage board's; a group column is only
              // a view of the events that share a value.
              canRename: stage != null && provider.access.canRenameStage,
              canDelete: stage != null && provider.access.canDeleteStage,
              onRename: (name) =>
                  provider.renameStage(stage!.id, name).catchError((e) {
                    if (context.mounted) {
                      CustomSnackbar.showError(
                        context,
                        "Couldn't rename stage",
                      );
                    }
                  }),
              onDelete: () async {
                final confirm = await CommonDialog.confirm(
                  context,
                  title: 'Delete Stage',
                  message: events.isEmpty
                      ? 'Are you sure you want to delete "${stage!.name}"?'
                      : 'Are you sure you want to delete "${stage!.name}"? It still '
                            'has ${events.length} event${events.length == 1 ? '' : 's'}.',
                  confirmText: 'Delete',
                );
                if (confirm != true || !context.mounted) return;
                try {
                  await provider.deleteStage(stage.id);
                } catch (e) {
                  if (context.mounted) {
                    CustomSnackbar.showError(
                      context,
                      cleanedError(e.toString()),
                    );
                  }
                }
              },
            ),
            Expanded(
              child: DragTarget<EventShort>(
                onWillAcceptWithDetails: (details) =>
                    column.accepts(details.data, provider),
                onAcceptWithDetails: (details) {
                  column
                      .drop(details.data, provider)
                      .catchError((e) {
                        if (context.mounted) {
                          CustomSnackbar.showError(
                            context,
                            "Couldn't move event",
                          );
                        }
                      });
                },
                builder: (context, candidateData, rejectedData) {
                  return Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(AppRadius.lg),
                      ),
                    ),
                    // Center (unlike SizedBox.shrink(), which asks for zero
                    // size) fills whatever space it's given rather than
                    // shrinking to its child, so this still claims the full
                    // drop-target area instead of collapsing to a
                    // zero-width sliver nothing can ever be dropped on.
                    child: events.isEmpty
                        ? Center(
                            child: Text(
                              'No event in this stage',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.secondaryLabelColor(isDark),
                              ),
                            ),
                          )
                        : ListView.builder(
                            // A little room below the last card so the
                            // column's own rounded bottom edge reads clearly
                            // instead of the last card sitting flush against
                            // it.
                            padding: const EdgeInsets.only(bottom: 10),
                            itemCount: events.length,
                            itemBuilder: (context, index) {
                              final event = events[index];
                              return Padding(
                                padding: KanbanBoard._cardMargin,
                                child: LongPressDraggable<EventShort>(
                                  data: event,
                                  // Moving a card is a write on the event: for
                                  // an account that can't make one the card is
                                  // shown but can't be picked up.
                                  maxSimultaneousDrags: cardsMove ? 1 : 0,
                                  // Lets the board auto-scroll horizontally
                                  // while a card is held near the screen's
                                  // left/right edge, to reach a column that's
                                  // currently off-screen.
                                  onDragUpdate: (details) =>
                                      onCardDragUpdate(details),
                                  onDragEnd: (_) => onCardDragEnd(),
                                  onDraggableCanceled: (_, _) =>
                                      onCardDragEnd(),
                                  onDragCompleted: onCardDragEnd,
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: SizedBox(
                                      width:
                                          KanbanBoard._listWidth -
                                          KanbanBoard._listPadding.horizontal -
                                          KanbanBoard._cardMargin.horizontal,
                                      child: Opacity(
                                        opacity: 0.9,
                                        child: _KanbanEventCard(event: event),
                                      ),
                                    ),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.3,
                                    child: _KanbanEventCard(event: event),
                                  ),
                                  child: _KanbanEventCard(event: event),
                                ),
                              );
                            },
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KanbanEventCard extends StatelessWidget {
  final EventShort event;

  const _KanbanEventCard({required this.event});

  Widget _avatar(BuildContext context, bool isDark) {
    final myAvatar = context.select<ProfileProvider, Uint8List?>(
      (profile) => profile.userAvatar,
    );
    final currentUserId = SessionService.instance.currentSession?.userId;
    final isMine = currentUserId != null && event.userId == currentUserId;
    final bytes = isMine && myAvatar != null ? myAvatar : event.image;

    return Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: ClipOval(
        child: bytes != null && bytes.isNotEmpty
            ? Image.memory(
                bytes,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Image.asset('assets/profile.jpg', fit: BoxFit.cover),
              )
            : Image.asset('assets/profile.jpg', fit: BoxFit.cover),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventDetailsScreen(id: event.id)),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOn(isDark),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                StatusColors.buildStatusBadge(
                  context,
                  getKanbanLabel(event.kanbanState),
                  color: getKanbanColor(event.kanbanState),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              event.location.isEmpty ? 'Online Event' : event.location,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: AppTheme.secondaryLabelColor(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCalendar03,
                  size: 14,
                  color: AppTheme.secondaryLabelColor(isDark),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    event.fullDate,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOn(isDark),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // Same activity indicator as the Home list card — tapping it
                // opens the same overlay, not just a static icon.
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) =>
                          ActivityOverlayScreen(eventShortDetails: event),
                    );
                  },
                  child: getIcont(event.activityTypeIcon, event.activityState),
                ),
                const Spacer(),
                // Flush with the card's right padding, under the status badge.
                _avatar(context, isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Column header (§11): a single pill combining the stage name and its
/// count — "New 2" — plus a "⋮" for the one real per-column action this app
/// has: Edit (rename) and Delete. Each is offered only when the server lets
/// the account do it ([canRename], [canDelete] — in practice Event
/// administrators), and the "⋮" is left off entirely when neither is, rather
/// than showing an empty or refused menu.
class _ColumnHeader extends StatelessWidget {
  final bool isDark;
  final String title;
  final int count;
  final bool canRename;
  final bool canDelete;
  final ValueChanged<String> onRename;
  final VoidCallback onDelete;

  const _ColumnHeader({
    required this.isDark,
    required this.title,
    required this.count,
    required this.canRename,
    required this.canDelete,
    required this.onRename,
    required this.onDelete,
  });

  Future<void> _promptRename(BuildContext context) async {
    final controller = TextEditingController(text: title);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _StageDialog(
        icon: HugeIcons.strokeRoundedPencilEdit02,
        title: 'Rename Stage',
        controller: controller,
        confirmLabel: 'Rename',
      ),
    );
    if (name == null || name.isEmpty || name == title) return;
    onRename(name);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // The header sits inside the package's own Column, which gives it
      // loose (not tight) width constraints — without this it shrinks to
      // the pill + kebab's own width instead of filling the column, so the
      // header visibly stops short of the column's right edge.
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      child: Row(
        children: [
          // Expanded, not a bare pill + Spacer: a Row hands its non-flex
          // children unbounded width, so the pill's own ellipsis never had a
          // limit to apply and a long stage name ran off the column.
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: StageCountPill(isDark: isDark, title: title, count: count),
            ),
          ),
          // The column's row-action popup. Its icons are the Mobo ones used on
          // the other cards: the grey square-and-pencil for Edit, the red trash
          // for Delete.
          if (canRename || canDelete)
            PopupMenuButton<String>(
              position: PopupMenuPosition.under,
              padding: EdgeInsets.zero,
              color: isDark ? AppTheme.darkPopupSurface : Colors.white,
              icon: Icon(
                Icons.more_vert,
                size: 18,
                color: AppTheme.secondaryLabelColor(isDark),
              ),
              onSelected: (value) {
                if (value == 'edit') {
                  _promptRename(context);
                } else if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (context) {
                final itemTextColor = isDark ? Colors.white : Colors.black87;
                return [
                  if (canRename)
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedPencilEdit02,
                            size: 20,
                            color: AppTheme.secondaryLabelColor(isDark),
                          ),
                          const SizedBox(width: 12),
                          Text('Edit', style: TextStyle(color: itemTextColor)),
                        ],
                      ),
                    ),
                  if (canDelete)
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedDelete02,
                            size: 20,
                            color: StatusColors.red,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Delete',
                            style: TextStyle(color: StatusColors.red),
                          ),
                        ],
                      ),
                    ),
                ];
              },
            ),
        ],
      ),
    );
  }
}

/// The black pill in a column header: the stage name and its event count.
///
/// The name gives way first, ellipsised, so a long stage name cannot push the
/// pill past the column and the count — the reason the pill is there — is
/// never the part that gets cut.
@visibleForTesting
class StageCountPill extends StatelessWidget {
  final bool isDark;
  final String title;
  final int count;

  const StageCountPill({
    super.key,
    required this.isDark,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: isDark ? Colors.black : Colors.white,
      fontSize: 13,
      fontWeight: FontWeight.w700,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          Text(' ($count)', maxLines: 1, style: style),
        ],
      ),
    );
  }
}

/// The "+ Add Stage" pill, the board's own trailing element (see
/// [KanbanBoard.listTarget]) — floats directly on the page background,
/// carrying no card shell of its own.
class _AddStageButton extends StatelessWidget {
  final HomeProvider provider;

  const _AddStageButton({required this.provider});

  Future<void> _promptAddStage(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _StageDialog(
        title: 'Add New Stage',
        controller: controller,
        confirmLabel: 'Create Stage',
        showCancel: false,
        hint: 'Enter stage name (e.g., "Qualified")',
        info:
            'The new stage will be added right before the "Add Stage" button.',
      ),
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    try {
      await provider.addStage(name);
    } catch (_) {
      if (!context.mounted) return;
      CustomSnackbar.showError(context, "Couldn't create the stage");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // §11's inner black button: rectangular, radius 8 — not a stadium pill.
    // Full width of its shell, icon + label centered rather than hugging
    // the left edge.
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: isDark ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: () => _promptAddStage(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // The pill's fill inverts in dark mode, so its content has
                // to invert with it — this was fixed white, so a dark-mode
                // white pill got white icon+text on it and looked blank.
                Icon(
                  Icons.add,
                  size: 16,
                  color: isDark ? Colors.black : Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  'Add Stage',
                  style: TextStyle(
                    color: isDark ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared shell for the Add/Rename stage dialogs: the title (with an optional
/// icon badge before it) + close, a labelled field, an optional info banner,
/// and the standard Cancel / Confirm footer — disabled until the name actually
/// changed.
class _StageDialog extends StatefulWidget {
  /// The round badge before the title; none for a plain title.
  final List<List<dynamic>>? icon;
  final String title;
  final TextEditingController controller;
  final String confirmLabel;
  final String? hint;
  final String? info;

  /// A Cancel button beside the confirm one. Off, the confirm button has the
  /// footer to itself — the × in the header already closes the dialog.
  final bool showCancel;

  const _StageDialog({
    this.icon,
    required this.title,
    required this.controller,
    required this.confirmLabel,
    this.hint,
    this.info,
    this.showCancel = true,
  });

  @override
  State<_StageDialog> createState() => _StageDialogState();
}

class _StageDialogState extends State<_StageDialog> {
  late bool _canConfirm = widget.controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // A phone on its side has ~360dp, and the keyboard this dialog opens with
    // takes most of it — tighter margins, and the title / buttons stay pinned
    // while the field scrolls (everything scrolls once even that won't fit).
    final short = context.isShortScreen;
    return Dialog(
      backgroundColor: AppTheme.surface(isDark),
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: short ? 8 : 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: EdgeInsets.all(short ? 16 : 20),
        child: PinnedFooterLayout(
          crossAxisAlignment: CrossAxisAlignment.start,
          scrollAllBelow: 150,
          gap: short ? 12 : 20,
          header: Row(
            children: [
              if (widget.icon != null) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: HugeIcon(
                    icon: widget.icon!,
                    size: 16,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              // The title takes the row after the badge (if any), so it starts
              // at the left. A Spacer beside this Expanded split the free
              // space with it and left the title floating mid-row.
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryOn(isDark),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedCancel01,
                  size: 20,
                  color: AppTheme.textPrimaryOn(isDark),
                ),
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              MoboTextField(
                controller: widget.controller,
                label: 'Stage Name',
                isRequired: true,
                hintText: widget.hint ?? 'Enter stage name',
                autofocus: true,
                onChanged: (v) =>
                    setState(() => _canConfirm = v.trim().isNotEmpty),
              ),
              if (widget.info != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),

                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: Colors.blueAccent.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.info!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.blueAccent,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          footer: widget.showCancel
              ? MoboButtonRow(
                  secondaryLabel: 'Cancel',
                  onSecondary: () => Navigator.pop(context),
                  primaryLabel: widget.confirmLabel,
                  onPrimary: _canConfirm
                      ? () =>
                            Navigator.pop(context, widget.controller.text.trim())
                      : null,
                )
              : MoboButton.filled(
                  label: widget.confirmLabel,
                  onPressed: _canConfirm
                      ? () =>
                            Navigator.pop(context, widget.controller.text.trim())
                      : null,
                ),
        ),
      ),
    );
  }
}

/// Kanban-shaped loading skeleton (CLAUDE.md §15): a few fake columns with
/// the real column shell, each holding a couple of card-shaped placeholders
/// the same size as an [EventShortCard], so loading and loaded states don't
/// visually jump.
class KanbanBoardShimmer extends StatelessWidget {
  const KanbanBoardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.grey.shade700 : Colors.grey.shade200;
    final highlight = isDark ? Colors.grey.shade600 : Colors.grey.shade50;

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (context, _) {
        return SizedBox(
          width: KanbanBoard._listWidth - 12,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                  child: Shimmer.fromColors(
                    baseColor: base,
                    highlightColor: highlight,
                    child: Container(
                      height: 22,
                      width: 120,
                      decoration: BoxDecoration(
                        color: base,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                ),
                // The placeholder cards are fixed-height, so on a short
                // (landscape) board they'd overflow the column. A
                // non-scrolling list inside Expanded just clips the extra
                // card instead.
                Expanded(
                  child: ListView(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: [
                      for (var i = 0; i < 2; i++)
                        Padding(
                          padding: KanbanBoard._cardMargin,
                          child: Shimmer.fromColors(
                            baseColor: base,
                            highlightColor: highlight,
                            child: Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: base,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
