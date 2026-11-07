import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_layout.dart';
import '../dialogs/pinned_footer_layout.dart';
import '../mobo/mobo_button.dart';

/// One entry of a Group By menu: what it is called and a line saying what it
/// does. The grouping enums of the screens that offer one implement this.
abstract interface class GroupByChoice {
  String get label;
  String get description;
}

/// Opens the "Filter & Group By" bottom sheet every list screen shares: the
/// screen's own filters on one tab, its Group By choice on the other.
///
/// The sheet owns the group-by choice and the tab; the filters are the
/// caller's. [filterTab] builds the Filter tab's content from whatever the
/// caller stages (a list it captured, mutated by chip taps) and calls the
/// `rebuild` it is handed after each change. Nothing reaches the screen until
/// Apply or Clear All, which close the sheet and then call [onApply] /
/// [onClear], so any other way of closing it leaves the list as it was.
///
/// Sizing: 85% of the window in portrait. A phone in landscape is only
/// ~300–400dp tall, so there the sheet may use almost the whole window, shrinks
/// to its content when that is shorter, is capped to a readable column and has
/// tighter margins. In both, the height is measured against what the keyboard
/// leaves (it is often still up from the search box the sheet was opened
/// from), and when even that can't hold the pinned header and footer the whole
/// sheet scrolls rather than overflowing.
Future<void> showFilterGroupBySheet<T extends GroupByChoice>(
  BuildContext context, {
  required List<T> groupByOptions,
  required T? initialGroupBy,
  required Widget Function(BuildContext context, bool short, VoidCallback rebuild)
  filterTab,
  required Future<void> Function(T? groupBy) onApply,
  required Future<void> Function() onClear,
  String title = 'Filter & Group By',

  // What "None" does on this screen, when "a simple list" isn't it.
  String noneDescription = 'Display as a simple list',
}) {
  final short = context.isShortScreen;
  final size = MediaQuery.sizeOf(context);

  return showModalBottomSheet(
    // §19 — transparent sheet + inner Container for top-only rounding.
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    context: context,
    constraints: BoxConstraints(
      minWidth: size.width,
      // On a short window the cap is applied in the sheet instead, against
      // the height left once the keyboard is counted.
      maxHeight: size.height * (short ? 1 : 0.85),
    ),
    builder: (_) => _FilterGroupBySheet<T>(
      title: title,
      groupByOptions: groupByOptions,
      initialGroupBy: initialGroupBy,
      filterTab: filterTab,
      noneDescription: noneDescription,
      onApply: onApply,
      onClear: onClear,
    ),
  );
}

class _FilterGroupBySheet<T extends GroupByChoice> extends StatefulWidget {
  final String title;
  final List<T> groupByOptions;
  final T? initialGroupBy;
  final Widget Function(BuildContext context, bool short, VoidCallback rebuild)
  filterTab;
  final String noneDescription;
  final Future<void> Function(T? groupBy) onApply;
  final Future<void> Function() onClear;

  const _FilterGroupBySheet({
    required this.title,
    required this.groupByOptions,
    required this.initialGroupBy,
    required this.filterTab,
    required this.noneDescription,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_FilterGroupBySheet<T>> createState() => _FilterGroupBySheetState<T>();
}

class _FilterGroupBySheetState<T extends GroupByChoice>
    extends State<_FilterGroupBySheet<T>>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(_onTabChanged);

  /// What is ticked in the Group By tab — only handed back by Apply.
  late T? _groupBy = widget.initialGroupBy;

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  /// Only the selected tab is built, so the sheet follows that tab's content.
  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _close(Future<void> Function() then) async {
    Navigator.pop(context);
    await then();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final short = context.isShortScreen;

    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    // On a short window: up to 92% of the window — all of what the keyboard
    // leaves, while it is up.
    final shortCap =
        (media.size.height - keyboard) * (keyboard > 0 ? 1 : 0.92);

    // The header and the Clear All / Apply footer stay pinned and the tab
    // between them scrolls, whatever height is left. Below ~190dp (a keyboard
    // on a phone in landscape) they scroll too.
    final content = PinnedFooterLayout(
      expandBody: !short,
      crossAxisAlignment: CrossAxisAlignment.start,
      scrollAllBelow: short ? 140 : 280,
      header: _header(isDark, short),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _tabs.index == 0
            ? KeyedSubtree(
                key: const ValueKey('filter'),
                child: widget.filterTab(context, short, _rebuild),
              )
            : KeyedSubtree(
                key: const ValueKey('groupBy'),
                child: _groupByTab(isDark),
              ),
      ),
      footer: _footer(isDark, short),
    );

    // Lifting the sheet by the keyboard inset (and the body shrinking to
    // what's left) keeps both buttons reachable.
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: short ? shortCap : double.infinity,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.grey[50],
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg),
            ),
          ),
          // One side inset for everything in the sheet — title, tabs, chips,
          // headings, Group By rows and footer all start on the same line.
          padding: const EdgeInsets.symmetric(
            horizontal: FilterSectionTitle.inset,
          ),
          // The window is 700–900dp wide, so on a short one the sheet is capped
          // to a readable column rather than stretched across it, and kept
          // clear of a notch.
          child: short
              ? SafeArea(
                  top: false,
                  bottom: false,
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: content,
                    ),
                  ),
                )
              : content,
        ),
      ),
    );
  }

  Widget _header(bool isDark, bool short) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // §19 drag handle.
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.only(top: short ? 6 : 12, bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Row(
          children: [
            // Flexible, so a large text-size setting cuts the title short
            // rather than pushing the close button off the sheet.
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.dark,
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedCancel01,
                color: isDark ? Colors.white : AppTheme.dark,
              ),
            ),
          ],
        ),
        SizedBox(height: short ? 4 : 8),
        _tabBar(isDark),
      ],
    );
  }

  Widget _tabBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: TabBar(
        controller: _tabs,
        indicator: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        indicatorPadding: const EdgeInsets.all(4),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(height: 48, text: 'Filter'),
          Tab(height: 48, text: 'Group By'),
        ],
      ),
    );
  }

  /// Spaced as mobo Billing's Group By tab: 20 above the heading and below it,
  /// 16 above and below each option's text (its row padding), and 10 either
  /// side of the rule under None.
  Widget _groupByTab(bool isDark) {
    final divider = isDark ? Colors.grey[700] : Colors.grey[300];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Group by',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[200] : Colors.grey[800],
          ),
        ),
        const SizedBox(height: 20),
        _GroupOption(
          title: 'None',
          description: widget.noneDescription,
          selected: _groupBy == null,
          onTap: () => setState(() => _groupBy = null),
        ),
        // A rule under None alone: it is the absence of grouping, not one of
        // the fields to group on.
        const SizedBox(height: 10),
        Divider(height: 1, thickness: 1, color: divider),
        const SizedBox(height: 10),
        for (final option in widget.groupByOptions)
          _GroupOption(
            title: option.label,
            description: option.description,
            selected: _groupBy == option,
            onTap: () => setState(() => _groupBy = option),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _footer(bool isDark, bool short) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(
          height: 1,
          thickness: 1,
          color: isDark ? Colors.grey[800] : Colors.grey.shade200,
        ),

        // Buttons — §5 two-button footer convention.
        Padding(
          padding: EdgeInsets.symmetric(vertical: short ? 8 : 16),
          child: MoboButtonRow(
            secondaryLabel: 'Clear All',
            onSecondary: () => _close(widget.onClear),
            primaryLabel: 'Apply',
            onPrimary: () => _close(() => widget.onApply(_groupBy)),
          ),
        ),
        SizedBox(height: short ? 4 : 16),
      ],
    );
  }
}

/// A heading inside a filter tab ("Event Type", "Others"): 14px w600 grey,
/// 24 above and 12 below. Pass [color] for the brand-coloured "Active Filters"
/// heading.
class FilterSectionTitle extends StatelessWidget {
  /// The side inset of every filter sheet; nothing inside adds its own.
  static const double inset = 16;

  final String text;
  final Color? color;

  /// Space above the heading; the first one in a tab sits closer to the tabs.
  final double top;

  const FilterSectionTitle(
    this.text, {
    super.key,
    this.color,
    this.top = 24,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color ?? AppTheme.secondaryLabelColor(isDark),
        ),
      ),
    );
  }
}

/// A group-by choice: a radio, a title and a line saying what it does. The
/// whole row is the target, not just the radio — a 20px circle is an unkind
/// thing to ask a thumb to hit.
class _GroupOption extends StatelessWidget {
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _GroupOption({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          // The radio sits level with the title and its description together,
          // as in a list tile, rather than with the title alone.
          child: Row(
            children: [
              _RadioMark(selected: selected),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.secondaryLabelColor(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The radio mark, drawn rather than Material's [Radio]: that one wants a
/// `groupValue` and an `onChanged`, both deprecated in favour of a `RadioGroup`
/// ancestor, and brings its own padding and splash that fight the row's.
/// Grey while unpicked, brand-coloured with a centre dot once picked.
class _RadioMark extends StatelessWidget {
  final bool selected;

  const _RadioMark({required this.selected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // A grey ring until picked, as Material's own unselected radio (and mobo
    // CRM's sheet); the chosen one turns brand-coloured and gains the centre dot.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected
              ? AppTheme.primaryColor
              : AppTheme.secondaryLabelColor(isDark),
          width: selected ? 2 : 1.5,
        ),
      ),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        scale: selected ? 1 : 0,
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }
}
