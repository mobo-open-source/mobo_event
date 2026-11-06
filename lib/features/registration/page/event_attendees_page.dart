import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_event/core/utils/screen_layout.dart';
import 'package:mobo_event/features/registration/provider/registration_provider.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/errors/universal_error_widget.dart';
import '../../../shared/widgets/filters/group_by_pill.dart';
import '../../../shared/widgets/groups/expandable_group_list.dart';
import '../../../shared/widgets/pagination/pagination_controls.dart';
import '../../../shared/widgets/shimmer_card/shimmer_card.dart';
import '../model/attendee_short_model.dart';
import '../widget/attendees_card.dart';
import '../widget/attendees_empty_state.dart';
import '../widget/attendees_search_event.dart';
import '../widget/floating_action_button_adding_attendees.dart';

class EventAttendeesPage extends StatefulWidget {
  final int eventId;

  /// The filter the list opens with. The attendee-count button on the event
  /// details passes 'Taken'; every other way in keeps this default.
  final String initialFilter;

  const EventAttendeesPage({
    super.key,
    required this.eventId,
    this.initialFilter = 'Unconfirmed or Registered',
  });

  @override
  State<EventAttendeesPage> createState() => _EventAttendeesPageState();
}

class _EventAttendeesPageState extends State<EventAttendeesPage> {
  final searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();

  /// Which groups of the grouped list are open. Held here, not by the list: a
  /// reload (a check-in, a refresh) swaps the list for a skeleton, and it would
  /// come back with every group shut.
  final GroupExpansion _groupExpansion = GroupExpansion();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      initialLoading(widget.eventId);
    });
  }

  Future initialLoading(int eventId) async {
    try {
      final provider = Provider.of<RegistrationProvider>(
        context,
        listen: false,
      );

      provider.clearFilter();
      provider.clearGroupBy();
      provider.setActiveFiltersEvents([widget.initialFilter]);

      await provider.loadAttendeesByEvent(eventId: eventId, reset: true);
    } catch (_) {
      // Shown by the list as an error view, from the provider's `loadError`.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Attendees",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      floatingActionButton: floatingActionButtonAddingAttendees(
        context,
        widget.eventId,
      ),
      // Landscape is ~300–400dp tall, so the search row and the filter/pagination
      // row stacked above the list left it a sliver. They become one toolbar
      // row under the (unchanged) app bar; the list stays a single scrolling
      // column under that.
      body: context.isLandscape
          ? _landscapeBody(context, isDark)
          : Column(
              children: [
                SizedBox(height: 10),
                AttendeeSearchEvent(
                  eventId: widget.eventId,
                  controller: searchController,
                  focusNode: searchFocusNode,
                ),
                SizedBox(height: 15),
                Consumer<RegistrationProvider>(
                  builder: (context, provider, child) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: _filterStatus(provider, isDark)),

                        Padding(
                          padding: const EdgeInsets.only(right: 20),
                          child: _pagination(provider, isDark),
                        ),
                      ],
                    );
                  },
                ),
                SizedBox(height: 5),

                Expanded(child: _attendeeList(isDark)),
              ],
            ),
    );
  }

  /// Inverted in dark mode, like the rest of this screen's controls — a fixed
  /// black pill nearly vanishes into the dark scaffold background.
  Widget _activeFiltersBadge(RegistrationProvider provider, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "${provider.activeFiltersByEvent.length} Active",
        style: TextStyle(color: isDark ? Colors.black : Colors.white),
      ),
    );
  }

  /// The left of the toolbar row: that nothing is applied, how many filters
  /// are, and/or what the list is grouped by.
  Widget _filterStatus(RegistrationProvider provider, bool isDark) {
    final hasFilters = provider.activeFiltersByEvent.isNotEmpty;
    if (!hasFilters && !provider.isGroupedEvent) {
      return const Padding(
        padding: EdgeInsets.only(left: 20),
        child: Text("No filters applied", style: TextStyle(fontSize: 12)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        // They scale down together on a narrow row rather than overflow it.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasFilters) _activeFiltersBadge(provider, isDark),
              if (hasFilters && provider.isGroupedEvent)
                const SizedBox(width: 8),
              if (provider.isGroupedEvent) _groupByPill(provider),
            ],
          ),
        ),
      ),
    );
  }

  /// Sized like [_activeFiltersBadge], so the two read as a pair.
  Widget _groupByPill(RegistrationProvider provider) {
    return GroupByPill(
      label: provider.groupByEvent!.label,
      height: null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      radius: 5,
      fontSize: 14,
    );
  }

  Widget _pagination(RegistrationProvider provider, bool isDark) {
    // A grouped list holds every attendee: a count, not pages.
    if (provider.isGroupedEvent) {
      return provider.totalRecordsEvent == 0
          ? const SizedBox.shrink()
          : PaginationCounterPill(text: provider.paginationTextEvent);
    }
    return PaginationControls(
      canGoToPreviousPage: provider.canGoPreviousEvent,
      canGoToNextPage: provider.canGoNextEvent,
      onPreviousPage: () => provider.previousPageEvent(),
      onNextPage: () => provider.nextPageEvent(),
      paginationText: provider.paginationTextEvent,
      totalCount: provider.totalRecordsEvent,
      isDark: isDark,
      theme: Theme.of(context),
    );
  }

  Widget _landscapeBody(BuildContext context, bool isDark) {
    // One toolbar row — search, filter count, pagination — under the app bar.
    // With the keyboard up there can be less than the toolbar plus a sliver of
    // list left; the body then scrolls as a whole rather than overflowing. It
    // is always wrapped (a no-op while it fits) so the search field keeps its
    // place in the tree — and its focus — as the keyboard opens.
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: SizedBox(
            height: math.max(constraints.maxHeight, 140),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: AttendeeSearchEvent(
                          eventId: widget.eventId,
                          controller: searchController,
                          focusNode: searchFocusNode,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      // "No filters applied" is dropped here — only a real
                      // count takes up room in the row.
                      Consumer<RegistrationProvider>(
                        builder: (context, provider, child) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (provider.activeFiltersByEvent.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                _activeFiltersBadge(provider, isDark),
                              ],
                              if (provider.isGroupedEvent) ...[
                                const SizedBox(width: 10),
                                _groupByPill(provider),
                              ],
                              const SizedBox(width: 10),
                              _pagination(provider, isDark),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Capped like the other single-column bodies: cards 700dp wide
                // leave the company / slot / ticket lines miles from the badge.
                Expanded(
                  child: ConstrainedContent(
                    maxWidth: 720,
                    child: _attendeeList(isDark, landscape: true),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Both lists leave room under the last card so the floating add button
  /// can't sit on top of it when scrolled to the end.
  Widget _attendeeList(bool isDark, {bool landscape = false}) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: Consumer<RegistrationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingEvent) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListView(
                children: const [
                  FullCardShimmer(height: 150),
                  FullCardShimmer(height: 150),
                  FullCardShimmer(height: 150),
                  FullCardShimmer(height: 150),
                  FullCardShimmer(height: 150),
                  FullCardShimmer(height: 150),
                ],
              ),
            );
          } else if (provider.fetchedAttendeesByEvent == null) {
            return ScrollableErrorView(
              error: provider.loadError ?? Exception('Unknown error'),
              onRetry: () async {
                try {
                  await provider.loadAttendeesByEvent(
                    eventId: widget.eventId,
                    reset: true,
                    search: searchController.text,
                  );
                } catch (_) {}
              },
            );
          } else if (provider.fetchedAttendeesByEvent!.isEmpty) {
            return AttendeesEmptyState(
              filtered:
                  provider.activeFiltersByEvent.isNotEmpty ||
                  searchController.text.isNotEmpty ||
                  provider.isGroupedEvent,
              onClear: () async {
                searchController.clear();
                provider.clearFilter();
                provider.setGroupByEvent(null);
                await provider.loadAttendeesByEvent(
                  eventId: widget.eventId,
                  reset: true,
                );
              },
              onRetry: () async {
                await provider.loadAttendeesByEvent(
                  eventId: widget.eventId,
                  search: searchController.text,
                  reset: true,
                );
              },
            );
          } else if (provider.isGroupedEvent) {
            return ExpandableGroupList<AttendeeShortModel>(
              groups: provider.groupedAttendeesEvent,
              expansion: _groupExpansion,
              // The group card's own margin from the screen edge — separate
              // from AttendeesCard's own 16px self-inset, which lines its
              // text up with the group header's.
              horizontalInset: 20,
              padding: const EdgeInsets.only(bottom: AppSpacing.fabClearance),
              keyboardDismissBehavior: landscape
                  ? ScrollViewKeyboardDismissBehavior.onDrag
                  : ScrollViewKeyboardDismissBehavior.manual,
              itemNoun: 'attendee',
              itemNounPlural: 'attendees',
              itemBuilder: (context, attendee) => AttendeesCard(
                key: ValueKey(attendee.id),
                id: widget.eventId,
                attendeeShortModel: attendee,
              ),
            );
          } else {
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: AppSpacing.fabClearance),
              keyboardDismissBehavior: landscape
                  ? ScrollViewKeyboardDismissBehavior.onDrag
                  : ScrollViewKeyboardDismissBehavior.manual,
              itemCount: provider.fetchedAttendeesByEvent!.length,
              itemBuilder: (context, index) {
                return AttendeesCard(
                  id: widget.eventId,
                  attendeeShortModel: provider.fetchedAttendeesByEvent![index],
                );
              },
            );
          }
        },
      ),
    );
  }

  Future<void> _onRefresh() async {
    try {
      final provider = Provider.of<RegistrationProvider>(
        context,
        listen: false,
      );
      await provider.loadAttendeesByEvent(reset: true, eventId: widget.eventId);
    } catch (_) {
      if (!mounted) return;
      final provider = Provider.of<RegistrationProvider>(
        context,
        listen: false,
      );
      if (provider.fetchedAttendeesByEvent != null) {
        CustomSnackbar.showError(context, "Refresh failed");
      }
    }
  }
}
