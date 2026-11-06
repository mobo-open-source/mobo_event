import 'package:flutter/material.dart';
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/features/profile/providers/profile_provider.dart';
import 'package:mobo_event/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/shimmer_card/shimmer_card.dart';
import '../../event/provider/event_detailed_provider.dart';
import '../../event/widget/add_floating_event.dart';
import '../../registration/page/registration_page.dart';
import '../providers/home_provider.dart';
import '../widgets/event_group_list.dart';
import '../widgets/event_short_card.dart';
import '../widgets/no_events_empty_state.dart';
import '../widgets/search_event.dart';
import '../widgets/kanban_board.dart';
import '../widgets/view_mode_selector.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_layout.dart';
import '../../../shared/widgets/filters/group_by_pill.dart';
import '../../../shared/widgets/errors/universal_error_widget.dart';
import '../../../shared/widgets/groups/expandable_group_list.dart';
import '../../../shared/widgets/pagination/pagination_controls.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();

  bool isInitialLoading = true;

  /// Which groups of the grouped List view are open. Held here, not by the
  /// list: a reload swaps the list for a skeleton, and it would come back shut.
  final GroupExpansion _groupExpansion = GroupExpansion();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initialLoading();
    });
  }

  /// Why the event list could not be loaded, or null. While set and there is
  /// nothing to show, the list area is the error view (with the server's own
  /// message) rather than an empty list.
  Object? _loadError;

  Future<void> initialLoading() async {
    try {
      setState(() {
        isInitialLoading = true;
        _loadError = null;
      });

      final homeProvider = Provider.of<HomeProvider>(context, listen: false);
      await homeProvider.fetchVersion();
      final eventProvider = Provider.of<EventDetailedProvider>(
        context,
        listen: false,
      );

      homeProvider.setActiveFilters([]);
      homeProvider.setGroupBy(null);

      await Future.wait([
        homeProvider.gettingStages(),
        eventProvider.loadFields(),
        eventProvider.loadFieldOfTicket(),
        homeProvider.loadEvents(),
      ]);
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    } finally {
      if (mounted) {
        setState(() => isInitialLoading = false);
      }
    }
  }

  /// Refresh event list
  Future<void> _onRefresh() async {
    try {
      final homeProvider = Provider.of<HomeProvider>(context, listen: false);
      await homeProvider.gettingStages();
      await homeProvider.loadEvents();
      if (mounted && _loadError != null) setState(() => _loadError = null);
    } catch (e) {
      if (!mounted) return;
      final provider = Provider.of<HomeProvider>(context, listen: false);
      // With events on screen a failed refresh is only a message; with none,
      // the error view takes the list's place.
      if (provider.eventList.isEmpty) {
        setState(() => _loadError = e);
      } else {
        CustomSnackbar.showError(context, "Refresh failed");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<HomeProvider, ProfileProvider>(
      builder: (context, provider, profileProvider, child) {
        if (isInitialLoading || provider.loading) {
          return Scaffold(
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: FullCardShimmer(height: 50, radius: 5),
                ),

                SizedBox(height: 10),

                const SizedBox(height: 20),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ListView.builder(
                      itemCount: 6,
                      itemBuilder: (_, __) => const FullCardShimmer(),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final isLoading = provider.isEventLoading || profileProvider.isLoading;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isLandscape =
            MediaQuery.orientationOf(context) == Orientation.landscape;

        final loadError = _loadError;
        final content = loadError != null && provider.eventList.isEmpty
            ? RefreshIndicator(
                onRefresh: _onRefresh,
                child: ScrollableErrorView(
                  error: loadError,
                  onRetry: initialLoading,
                ),
              )
            : isLoading
            ? (provider.viewMode == HomeViewMode.kanban
                  ? const KanbanBoardShimmer()
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ListView.builder(
                        itemCount: 5,
                        itemBuilder: (_, _) => const FullCardShimmer(),
                      ),
                    ))
            : RefreshIndicator(
                onRefresh: _onRefresh,
                child: provider.viewMode == HomeViewMode.kanban
                    ? _refreshableKanbanBoard(provider, compact: isLandscape)
                    : _buildEventList(provider),
              );

        // Landscape is only ~half as tall as portrait, so the stacked
        // search / filter-row / bottom-gap layout left the board a sliver.
        // It gets a single-row toolbar, no bottom gap, and the floating
        // buttons move to a rail on the left, beside the board — the width
        // is free there, the height isn't.
        if (isLandscape) {
          return Scaffold(
            body: SafeArea(
              top: false,
              child: _scrollWhenCramped(
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (provider.access.canCreateEvent ||
                        provider.access.canMarkAttended)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 20,
                          right: 4,
                          bottom: 12,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (provider.access.canCreateEvent)
                              floatingActionButtonAddingEvent(context),
                            if (provider.access.canCreateEvent &&
                                provider.access.canMarkAttended)
                              const SizedBox(height: 16),
                            if (provider.access.canMarkAttended)
                              _qrButton(size: 56),
                          ],
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SearchEvent(
                                    controller: searchController,
                                    focusNode: searchFocusNode,
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                // "No filters applied" is dropped here, so only
                                // a real count takes up room in the row.
                                if (provider.activeFilters.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  _activeFiltersChip(provider, isDark),
                                ],
                                if (provider.isGrouped) ...[
                                  const SizedBox(width: 10),
                                  GroupByPill(label: provider.groupBy!.label),
                                ],
                                const SizedBox(width: 10),
                                ViewModeSelector(
                                  value: provider.viewMode,
                                  onChanged: provider.setViewMode,
                                ),
                                const SizedBox(width: 10),
                                _paginationControl(provider, isDark),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(child: content),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          body: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tight gaps around the header (search + the filter row):
                  // it sits close under the app bar and the list starts close
                  // under it, instead of 7 / 16 / 16 of empty screen.
                  const SizedBox(height: 4),
                  SearchEvent(
                    controller: searchController,
                    focusNode: searchFocusNode,
                  ),

                  const SizedBox(height: 10),

                  // Active-filters chip, the Kanban/List selector and the
                  // pagination pill all share one row, each 36px tall.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        // §18: an explicit "No filters applied" when there
                        // are none, rather than just leaving the spot blank.
                        // Expanded + a left Align, not Flexible + Spacer: those
                        // two split the free space between them, so the chip
                        // was cut off ("1 Ac…") at half of what was actually
                        // left. This takes everything the fixed-width controls
                        // leave, and only ellipsises once that truly runs out
                        // (narrow screens) instead of overflowing the row.
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _filterStatus(provider, isDark),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ViewModeSelector(
                          value: provider.viewMode,
                          onChanged: provider.setViewMode,
                        ),
                        const SizedBox(width: 10),
                        _paginationControl(provider, isDark),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  Expanded(child: content),

                  // The Kanban board keeps the band under it that the QR
                  // button floats in. The list runs to the bottom of the
                  // screen and clears the button with its own bottom padding
                  // instead (see [_listBottomClearance]), so no strip of empty
                  // screen is left under the last card.
                  if (provider.viewMode == HomeViewMode.kanban)
                    const SizedBox(height: 70),
                ],
              ),

              // Creating an event needs create access on `event.event`.
              if (provider.access.canCreateEvent)
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.7,
                  right: 20,
                  child: floatingActionButtonAddingEvent(context),
                ),

              // QR Button — scanning marks the registration attended, a write
              // on `event.registration`.
              if (provider.access.canMarkAttended)
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(child: _qrButton(size: 70)),
                ),
            ],
          ),
        );
      },
    );
  }

  /// What the left of the toolbar row says about the query: that nothing is
  /// applied, how many filters are, and/or what the list and board are
  /// grouped by.
  Widget _filterStatus(HomeProvider provider, bool isDark) {
    final hasFilters = provider.activeFilters.isNotEmpty;
    final grouped = provider.isGrouped;

    // §18: an explicit "No filters applied" when there are none — unless a
    // Group By pill already says something about the query.
    if (!hasFilters && !grouped) {
      return Text(
        'No filters applied',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isDark
              ? Colors.white70
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      );
    }
    if (!grouped) return _activeFiltersChip(provider, isDark);
    final pill = GroupByPill(label: provider.groupBy!.label);
    if (!hasFilters) return pill;

    // Both: they scale down together on a narrow row rather than overflow it.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _activeFiltersChip(provider, isDark),
          const SizedBox(width: 8),
          pill,
        ],
      ),
    );
  }

  /// Inverted in dark mode, like the status tabs below, so the chip doesn't
  /// vanish into the near-black background. The text scales down when the row
  /// is too tight for it, rather than ending in "…" — and FittedBox centres it
  /// in the 36px without the chip stretching across the Expanded, as
  /// `alignment:` would.
  Widget _activeFiltersChip(HomeProvider provider, bool isDark) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          "${provider.activeFilters.length} Active",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  /// Kanban shows every stage's events at once (no paging), and so does a
  /// grouped list (each group holds all of its events), so both keep the plain
  /// count pill; only the ungrouped List view pages through `eventList`. All
  /// use the same pill, so flipping views doesn't change it.
  Widget _paginationControl(HomeProvider provider, bool isDark) {
    if (provider.viewMode == HomeViewMode.list && !provider.isGrouped) {
      return PaginationControls(
        canGoToPreviousPage: provider.canGoPrevious,
        canGoToNextPage: provider.canGoNext,
        onPreviousPage: provider.previousPage,
        onNextPage: provider.nextPage,
        paginationText: provider.paginationText,
        totalCount: provider.totalRecords,
        isDark: isDark,
        theme: Theme.of(context),
      );
    }
    // No count on an empty board or list.
    if (provider.eventList.isEmpty) return const SizedBox.shrink();
    return PaginationCounterPill(
      text:
          '1-${provider.eventList.length} / '
          '${provider.eventList.length}',
    );
  }

  Widget _qrButton({required double size}) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RegistrationPage()),
        );
      },
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: primaryColor,
          shape: BoxShape.circle,
          boxShadow: [AppShadows.cardShadow],
        ),
        child: Icon(
          Icons.qr_code_scanner,
          color: Colors.white,
          size: size * 0.45,
        ),
      ),
    );
  }

  /// Least height the landscape body is laid out at. With the keyboard open on
  /// a phone on its side only ~100–150dp is left for the body — less than the
  /// toolbar plus one Kanban column header — so below this the body keeps this
  /// height and scrolls instead of overflowing.
  static const double _minLandscapeBodyHeight = 200;

  Widget _scrollWhenCramped(Widget body) {
    // The same widgets in both cases — only the height differs. Swapping to a
    // different tree when the keyboard opens would rebuild the search field
    // under the user's finger, drop its focus and close the keyboard again.
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight < _minLandscapeBodyHeight
            ? _minLandscapeBodyHeight
            : constraints.maxHeight;
        return SingleChildScrollView(
          child: SizedBox(height: height, child: body),
        );
      },
    );
  }

  /// Least height the Kanban board is laid out at, in either orientation. A
  /// short space under the toolbar (keyboard open, small screen) used to
  /// squeeze the columns below their own header's height and overflow; the
  /// surrounding list scrolls instead.
  static const double _minBoardHeight = 180;

  /// drag_and_drop_lists hard-codes `NeverScrollableScrollPhysics` on every
  /// column's own card list — there is no per-column scrolling in this
  /// package, so [KanbanBoard] now builds each column's card list itself
  /// (see its own doc) and genuinely scrolls it within whatever height it's
  /// given — no need to grow the whole board to fit the busiest column
  /// anymore, a plain bounded height is enough.
  Widget _refreshableKanbanBoard(
    HomeProvider provider, {
    required bool compact,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: constraints.maxHeight < _minBoardHeight
                  ? _minBoardHeight
                  : constraints.maxHeight,
              child: KanbanBoard(
                provider: provider,
                compact: compact,
                onClearFilters: () => _clearFilters(provider),
              ),
            ),
          ],
        );
      },
    );
  }

  /// The empty state's Clear All Filters: filters, search and group-by go
  /// together.
  Future<void> _clearFilters(HomeProvider provider) async {
    provider.setActiveFilters([]);
    provider.setGroupBy(null);
    searchController.clear();
    await provider.loadEvents();
  }

  /// The QR button's top, measured up from the bottom of the screen: it sits
  /// 40 up and is 70 tall.
  static const double _qrTop = 40 + 70;

  /// Bottom padding that lets the last card (or group) scroll clear of the
  /// floating buttons now that the portrait list runs to the bottom of the
  /// screen: the QR button when this account can scan, else the create
  /// button's [AppSpacing.fabClearance]. In landscape the buttons are in a rail
  /// beside the list, so only the usual clearance applies.
  double _listBottomClearance(HomeProvider provider) {
    if (context.isLandscape || !provider.access.canMarkAttended) {
      return AppSpacing.fabClearance;
    }
    return _qrTop + 16;
  }

  Widget _buildEventList(HomeProvider provider) {
    // No tab bar any more — List shows every event that matches the
    // current search/filter, unfiltered by stage (Kanban is what groups by
    // stage now).
    if (provider.eventList.isEmpty) {
      final hasFilters =
          provider.activeFilters.isNotEmpty ||
          searchController.text.isNotEmpty ||
          provider.isGrouped;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // The top gap centres the message in a tall window; on a short
          // one (landscape) it would push it off the screen.
          SizedBox(height: context.isShortScreen ? 0 : 120),
          NoEventsEmptyState(
            showClearFilters: hasFilters,
            onClearFilters: () => _clearFilters(provider),
          ),
        ],
      );
    }

    // A Group By replaces the pages with collapsible groups.
    if (provider.isGrouped) {
      return EventGroupList(
        groups: provider.groupedEvents,
        pageSize: provider.pageSize,
        expansion: _groupExpansion,
        bottomPadding: _listBottomClearance(provider),
      );
    }

    final paged = provider.pagedEventList;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      // Room for the last card to scroll clear of the floating buttons.
      padding: EdgeInsets.only(bottom: _listBottomClearance(provider)),
      itemCount: paged.length,
      itemBuilder: (context, index) {
        return EventShortCard(eventShortDetails: paged[index]);
      },
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }
}
