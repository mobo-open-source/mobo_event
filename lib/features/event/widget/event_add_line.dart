import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobo_event/core/theme/app_theme.dart';
import 'package:mobo_event/features/documentation/pages/documentation_screen.dart';
import 'package:mobo_event/features/event/widget/option_widget.dart';
import 'package:mobo_event/features/event/widget/ticket_line_widget.dart';
import 'package:mobo_event/features/questions/pages/event_question_page.dart';
import 'package:mobo_event/features/scheduler/page/mail_scheduler_screen.dart';
import 'package:mobo_event/shared/widgets/widget_card/card_widget.dart';

class EventAddLine extends StatefulWidget {
  final int eventId;

  /// True when the parent gives this a bounded height to fill (Details'
  /// landscape side pane). The tab card then takes all of it, instead of
  /// sizing itself off the window height the way it does in the portrait
  /// scroll view, where its height is otherwise unbounded.
  final bool fillHeight;

  const EventAddLine({
    super.key,
    required this.eventId,
    this.fillHeight = false,
  });

  @override
  State<EventAddLine> createState() => _EventAddLineState();
}

/// Swipeable like mobo CRM's quotation-form tabs (`QuotationTabBar`): a
/// [TabController] drives both the pill row and a [TabBarView] for the
/// content below it, so dragging the panel moves between tabs the same as
/// tapping a pill does, and the active pill tracks the drag live rather than
/// only snapping once it settles.
class _EventAddLineState extends State<EventAddLine>
    with SingleTickerProviderStateMixin {
  List<String> options = [
    "Tickets",
    "Communication",
    "Questions",
    "Notes & documents",
  ];

  late final TabController _tabController;

  /// Scrolls the pill row so the active pill is never off the edge of the
  /// strip — needed here (unlike CRM's three short labels) since a phone-
  /// width screen can't fit all four of these pills at once.
  final ScrollController _tabScrollController = ScrollController();
  late final List<GlobalKey> _tabKeys;

  /// The pill last brought into view, so a settling swipe doesn't re-trigger
  /// [_scrollToTab] on every animation frame once it has arrived.
  int _lastScrolledIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabKeys = List.generate(options.length, (_) => GlobalKey());
    _tabController = TabController(length: options.length, vsync: this)
      ..animation!.addListener(_onAnimationChanged);
  }

  @override
  void dispose() {
    _tabController.animation!.removeListener(_onAnimationChanged);
    _tabController.dispose();
    _tabScrollController.dispose();
    super.dispose();
  }

  void _onAnimationChanged() {
    final roundedIndex = _tabController.animation!.value.round();
    if (roundedIndex != _lastScrolledIndex) {
      _lastScrolledIndex = roundedIndex;
      _scrollToTab(roundedIndex);
    }
  }

  void _scrollToTab(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_tabScrollController.hasClients) return;
      final tabContext = _tabKeys[index].currentContext;
      if (tabContext == null) return;
      _tabScrollController.position.ensureVisible(
        tabContext.findRenderObject()!,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    });
  }

  /// The pill row. [padding] is the list's own scroll padding, not a Padding
  /// around it: that clipped the pills on a hard line inset from the screen's
  /// edge ("Communication" showing as "mmunication"), where now they scroll
  /// out at the edge itself.
  Widget _tabs({required EdgeInsets padding}) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: padding,
        controller: _tabScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          // Each pill rebuilds off the controller's own animation, so the
          // highlight follows a drag frame by frame instead of jumping
          // only once the page settles on an index.
          return AnimatedBuilder(
            animation: _tabController.animation!,
            builder: (context, _) {
              final activeIndex = _tabController.animation!.value.round();
              return OptionWidget(
                key: _tabKeys[index],
                title: options[index],
                isActive: activeIndex == index,
                onTap: () => _tabController.animateTo(index),
              );
            },
          );
        },
      ),
    );
  }

  /// Gives each tab page its own side inset. The card holds the pages with no
  /// side padding of its own (and clips to its rounded corners), so a swipe
  /// carries them across the whole card — not stopping at a hard line inside
  /// it — and the contents of two neighbouring pages are `2 × inset` apart.
  List<Widget> _inset(List<Widget> pages, double inset) => [
    for (final page in pages)
      Padding(
        padding: EdgeInsets.symmetric(horizontal: inset),
        child: page,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    List<Widget> containers = [
      TicketLineWidget(eventId: widget.eventId),
      MailScheduler(eventId: widget.eventId),
      EventQuestionPage(eventId: widget.eventId),
      DocumentationScreen(),
    ];

    if (widget.fillHeight) return _filled(context, containers);

    // 47% of the window is right for a phone held upright, but it shrinks to
    // a sliver in a short window, so the panel never gets below 280.
    final panelHeight = math.max(
      MediaQuery.of(context).size.height * 0.47,
      280.0,
    );

    return Column(
      children: [
        const SizedBox(height: 10),
        _tabs(padding: const EdgeInsets.symmetric(horizontal: 20)),
        const SizedBox(height: 10),
        CardWidget(
          // No side padding, and clipped to the card's corners: the pages
          // carry the 20px themselves (see [_inset]) so a swipe runs them to
          // the card's edge. 10 above, and 20 below — the same as the pages'
          // inset at the sides, so the content (the empty state's card, the
          // end of a list) is as far from the bottom edge as from the left and
          // right ones.
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 20),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: panelHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: _inset(containers, 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Landscape pane: tabs on top and the card below them filling whatever
  /// height is left. Same surface as [CardWidget], with tighter margins and
  /// padding since a phone on its side has no height to spare.
  ///
  /// The card is never shorter than 150dp: with the keyboard up the pane can
  /// be left with less than the tab content needs, and the pane then scrolls
  /// instead of overflowing. Otherwise the content fits the pane exactly and
  /// nothing scrolls.
  Widget _filled(BuildContext context, List<Widget> containers) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        // The gaps and tab row above the card: 8 + 40 + 8.
        const chrome = 56.0;
        final cardHeight = math.max(constraints.maxHeight - chrome, 150.0);
        return SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 8),
              _tabs(padding: const EdgeInsets.fromLTRB(8, 0, 20, 0)),
              const SizedBox(height: 8),
              SizedBox(
                height: cardHeight,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(6, 0, 18, 12),
                  // No side padding, and clipped to the corners: the pages
                  // carry the 16px themselves (see [_inset]).
                  padding: const EdgeInsets.fromLTRB(0, 6, 0, 4),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppTheme.surface(isDark),
                    border: isDark
                        ? Border.all(color: Colors.grey[800]!)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [AppShadows.cardShadow],
                  ),
                  child: TabBarView(
                    controller: _tabController,
                    children: _inset(containers, 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
