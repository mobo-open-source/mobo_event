import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_layout.dart';
import 'group_section.dart';

/// Which groups of a grouped list are open, and how many items each shows.
///
/// Kept by the screen rather than by [ExpandableGroupList], because the screen
/// swaps the list for a loading skeleton whenever it reloads — after an event
/// is edited, an attendee checked in, a pull to refresh — and a list that kept
/// its own state would come back with every group shut again.
class GroupExpansion {
  /// A group the user has opened or closed, by [GroupSection.key]. Absent means
  /// the default.
  final Map<String, bool> toggled = {};

  /// How many items a group shows, once "Show more" has been used.
  final Map<String, int> shown = {};
}

/// A grouped list: one collapsible card per group — its name and item count —
/// that opens onto the group's items, the way Odoo's grouped list view does.
/// Drawn like mobo Billing's grouped lists: the items sit inside the group's
/// own card, under a hairline, rather than in a panel hung beneath it.
///
/// Groups start collapsed, as they do in Odoo (a lone group opens, there being
/// nothing to choose between), and a group shows its first [pageSize] items
/// with a "Show more" under them, so opening a big group doesn't build every
/// card at once. Closed groups cost one tile, however many items they hold.
class ExpandableGroupList<T> extends StatefulWidget {
  final List<GroupSection<T>> groups;

  /// Builds one item's card. Give it a key — items move between groups.
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Open/closed state, owned by the screen (see [GroupExpansion]). Without
  /// one the list keeps its own, which dies with it.
  final GroupExpansion? expansion;

  /// Items a group shows before "Show more".
  final int pageSize;

  /// Space between the screen edge and the group's card — match the item
  /// cards' own, so ungrouped and grouped lists start on the same line.
  final double horizontalInset;

  /// Room around the items inside an open group. Only vertical by default:
  /// the item cards bring their own side inset. Set it so the first and last
  /// card end up 16 from the group's edges, whatever margins they carry.
  final EdgeInsetsGeometry bodyPadding;

  /// Caps and centres the tile on a wide landscape window, for cards that do
  /// the same ([ConstrainedContent]).
  final bool constrainInLandscape;

  /// Room around the list — under the last group, say, so a floating button
  /// can't sit on its last card.
  final EdgeInsetsGeometry? padding;

  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  final String itemNoun;

  /// Plural of [itemNoun], for the "3 events" under a group's name.
  final String itemNounPlural;

  const ExpandableGroupList({
    super.key,
    required this.groups,
    required this.itemBuilder,
    this.expansion,
    this.pageSize = 20,
    this.horizontalInset = 15,
    this.bodyPadding = const EdgeInsets.symmetric(vertical: 10),
    this.constrainInLandscape = false,
    this.padding,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.itemNoun = 'item',
    this.itemNounPlural = 'items',
  });

  @override
  State<ExpandableGroupList<T>> createState() => _ExpandableGroupListState<T>();
}

class _ExpandableGroupListState<T> extends State<ExpandableGroupList<T>> {
  final GroupExpansion _own = GroupExpansion();

  GroupExpansion get _expansion => widget.expansion ?? _own;

  bool _isExpanded(GroupSection<T> group) =>
      _expansion.toggled[group.key] ?? widget.groups.length == 1;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: widget.padding,
      keyboardDismissBehavior: widget.keyboardDismissBehavior,
      itemCount: widget.groups.length,
      itemBuilder: (context, index) {
        final group = widget.groups[index];
        return _GroupBlock<T>(
          // Keeps a group's open/close animation with the group when the one
          // above it appears or goes (a filter changed what is in the list).
          key: ValueKey(group.key),
          group: group,
          expanded: _isExpanded(group),
          shown: _expansion.shown[group.key] ?? widget.pageSize,
          itemBuilder: widget.itemBuilder,
          horizontalInset: widget.horizontalInset,
          bodyPadding: widget.bodyPadding,
          constrainInLandscape: widget.constrainInLandscape,
          itemNoun: widget.itemNoun,
          itemNounPlural: widget.itemNounPlural,
          onToggle: () => setState(
            () => _expansion.toggled[group.key] = !_isExpanded(group),
          ),
          onShowMore: () => setState(
            () => _expansion.shown[group.key] =
                (_expansion.shown[group.key] ?? widget.pageSize) +
                widget.pageSize,
          ),
        );
      },
    );
  }
}

/// A group's card: its header, with its items folding open beneath it.
class _GroupBlock<T> extends StatefulWidget {
  final GroupSection<T> group;
  final bool expanded;
  final int shown;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final double horizontalInset;
  final EdgeInsetsGeometry bodyPadding;
  final bool constrainInLandscape;
  final String itemNoun;
  final String itemNounPlural;
  final VoidCallback onToggle;
  final VoidCallback onShowMore;

  const _GroupBlock({
    super.key,
    required this.group,
    required this.expanded,
    required this.shown,
    required this.itemBuilder,
    required this.horizontalInset,
    required this.bodyPadding,
    required this.constrainInLandscape,
    required this.itemNoun,
    required this.itemNounPlural,
    required this.onToggle,
    required this.onShowMore,
  });

  @override
  State<_GroupBlock<T>> createState() => _GroupBlockState<T>();
}

class _GroupBlockState<T> extends State<_GroupBlock<T>>
    with SingleTickerProviderStateMixin {
  // §21 — a state-driven reveal stays under 300ms.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: widget.expanded ? 1 : 0,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void didUpdateWidget(_GroupBlock<T> old) {
    super.didUpdateWidget(old);
    if (widget.expanded != old.expanded) {
      widget.expanded ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.group.items;
    final visible = items.length < widget.shown ? items.length : widget.shown;
    final remaining = items.length - visible;

    final cards = Column(
      children: [
        for (final item in items.take(visible))
          widget.itemBuilder(context, item),
        if (remaining > 0)
          _ShowMore(remaining: remaining, onTap: widget.onShowMore),
      ],
    );

    final header = _GroupHeader(
      label: widget.group.label,
      count: items.length,
      noun: widget.itemNoun,
      nounPlural: widget.itemNounPlural,
      expanded: widget.expanded,
      onTap: widget.onToggle,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // One card per group, header and items alike (mobo Billing's
    // GroupSectionCard): §12's shell and shadow, no outline.
    final card = Container(
      margin: EdgeInsets.fromLTRB(
        widget.horizontalInset,
        0,
        widget.horizontalInset,
        12,
      ),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
            color: Colors.black.withValues(alpha: 0.08),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            AnimatedBuilder(
              animation: _curve,
              // The cards are only built while the group is open or closing:
              // a collapsed group costs one header, however many items it
              // holds.
              builder: (context, child) => _controller.isDismissed
                  ? const SizedBox(width: double.infinity)
                  : ClipRect(
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: _curve.value,
                        child: child,
                      ),
                    ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: isDark ? Colors.grey[700] : Colors.grey[200],
                  ),
                  Padding(padding: widget.bodyPadding, child: cards),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return widget.constrainInLandscape && context.isLandscape
        ? ConstrainedContent(child: card)
        : card;
  }
}

/// The top of a group's card: the group's name over its count, and a chevron
/// that turns as the group opens.
class _GroupHeader extends StatelessWidget {
  final String label;
  final int count;
  final String noun;
  final String nounPlural;
  final bool expanded;
  final VoidCallback onTap;

  const _GroupHeader({
    required this.label,
    required this.count,
    required this.noun,
    required this.nounPlural,
    required this.expanded,
    required this.onTap,
  });

  String get _countText => count == 1 ? '1 $noun' : '$count $nounPlural';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      expanded: expanded,
      label: '$label, $_countText',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.valueColor(isDark),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _countText,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.secondaryLabelColor(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: Icon(
                  Icons.keyboard_arrow_down,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Under a group's cards when it has more than it shows.
class _ShowMore extends StatelessWidget {
  final int remaining;
  final VoidCallback onTap;

  const _ShowMore({required this.remaining, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.primaryColor,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        child: Text('Show $remaining more'),
      ),
    );
  }
}
