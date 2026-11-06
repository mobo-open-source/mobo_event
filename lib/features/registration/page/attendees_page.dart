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
import '../widget/floating_action_button_adding_attendees.dart';
import '../widget/search_filter.dart';

class AttendeesPage extends StatefulWidget {
  const AttendeesPage({super.key});
  @override
  State<AttendeesPage> createState() => _AttendeesPageState();
}

class _AttendeesPageState extends State<AttendeesPage> {
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
      initialLoading();
    });
  }

  Future initialLoading() async {
    try {
      final provider = Provider.of<RegistrationProvider>(
        context,
        listen: false,
      );
      provider.clearFilter();
      provider.clearGroupBy();
      provider.setActiveFiltersTotal(['Ongoing Events']);
      await provider.loadAttendees(reset: true);
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
          onTap: () => Navigator.pop(context),
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

      floatingActionButton: floatingActionButtonAddingAttendees(context, null),

      // Landscape is ~300–400dp tall, so the search row and the filter/pagination
      // row stacked above the list left it a sliver. They become one toolbar
      // row under the (unchanged) app bar; the list stays a single scrolling
      // column under that.
      body: context.isLandscape
          ? _landscapeBody(context, isDark)
          : Column(
              children: [
                SizedBox(height: 10),
                SearchFilter(
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
                SizedBox(height: 10),

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
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        "${provider.activeFiltersByTotal.length} Active",
        style: TextStyle(color: isDark ? Colors.black : Colors.white),
      ),
    );
  }

  /// The left of the toolbar row: that nothing is applied, how many filters
  /// are, and/or what the list is grouped by.
  Widget _filterStatus(RegistrationProvider provider, bool isDark) {
    final hasFilters = provider.activeFiltersByTotal.isNotEmpty;
    if (!hasFilters && !provider.isGroupedTotal) {
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
              if (hasFilters && provider.isGroupedTotal)
                const SizedBox(width: 8),
              if (provider.isGroupedTotal)
                GroupByPill(
                  label: provider.groupByTotal!.label,
                  height: null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  radius: 15,
                  fontSize: 14,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pagination(RegistrationProvider provider, bool isDark) {
    // A grouped list holds every attendee: a count, not pages.
    if (provider.isGroupedTotal) {
      return provider.totalRecords == 0
          ? const SizedBox.shrink()
          : PaginationCounterPill(text: provider.paginationText);
    }
    return PaginationControls(
      canGoToPreviousPage: provider.canGoPrevious,
      canGoToNextPage: provider.canGoNext,
      onPreviousPage: () => provider.previousPage(),
      onNextPage: () => provider.nextPage(),
      paginationText: provider.paginationText,
      totalCount: provider.totalRecords,
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
                        child: SearchFilter(
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
                              if (provider.activeFiltersByTotal.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                _activeFiltersBadge(provider, isDark),
                              ],
                              if (provider.isGroupedTotal) ...[
                                const SizedBox(width: 10),
                                GroupByPill(
                                  label: provider.groupByTotal!.label,
                                  height: null,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  radius: 15,
                                  fontSize: 14,
                                ),
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
          if (provider.isLoading) {
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
          } else if (provider.fetchedAttendees == null) {
            return ScrollableErrorView(
              error: provider.loadError ?? Exception('Unknown error'),
              onRetry: () async {
                try {
                  await provider.loadAttendees(
                    reset: true,
                    search: searchController.text,
                  );
                } catch (_) {}
              },
            );
          } else if (provider.fetchedAttendees!.isEmpty) {
            return AttendeesEmptyState(
              filtered:
                  provider.activeFiltersByTotal.isNotEmpty ||
                  searchController.text.isNotEmpty ||
                  provider.isGroupedTotal,
              onClear: () async {
                provider.clearFilter();
                provider.setGroupByTotal(null);
                searchController.clear();
                await provider.loadAttendees(reset: true);
              },
              onRetry: () async {
                await provider.loadAttendees(
                  reset: true,
                  search: searchController.text,
                );
              },
            );
          } else if (provider.isGroupedTotal) {
            return ExpandableGroupList<AttendeeShortModel>(
              groups: provider.groupedAttendeesTotal,
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
                attendeeShortModel: attendee,
              ),
            );
          } else {
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: AppSpacing.fabClearance),
              keyboardDismissBehavior: landscape
                  ? ScrollViewKeyboardDismissBehavior.onDrag
                  : ScrollViewKeyboardDismissBehavior.manual,
              itemCount: provider.fetchedAttendees!.length,
              itemBuilder: (context, index) {
                return AttendeesCard(
                  attendeeShortModel: provider.fetchedAttendees![index],
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
      await provider.loadAttendees(reset: true);
    } catch (_) {
      if (!mounted) return;
      // With the list on screen a failed refresh is only a message; without
      // one the error view has taken its place.
      final provider = Provider.of<RegistrationProvider>(
        context,
        listen: false,
      );
      if (provider.fetchedAttendees != null) {
        CustomSnackbar.showError(context, "Refresh failed");
      }
    }
  }
}
