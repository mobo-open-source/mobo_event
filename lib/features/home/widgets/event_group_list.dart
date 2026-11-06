import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/groups/expandable_group_list.dart';
import '../model/event_group.dart';
import 'event_short_card.dart';

/// The Home List view when a Group By is applied: one collapsible tile per
/// group that opens onto the group's event cards. The behaviour — collapsed
/// to start, "Show more", the open/close animation — is
/// [ExpandableGroupList]'s; this only says what a card is.
class EventGroupList extends StatelessWidget {
  final List<EventGroup> groups;

  /// Events a group shows before "Show more".
  final int pageSize;

  /// Which groups are open, kept by the screen so a reload doesn't shut them.
  final GroupExpansion? expansion;

  /// Room under the last group to scroll clear of the floating buttons.
  final double bottomPadding;

  const EventGroupList({
    super.key,
    required this.groups,
    this.pageSize = 20,
    this.expansion,
    this.bottomPadding = AppSpacing.fabClearance,
  });

  @override
  Widget build(BuildContext context) {
    return ExpandableGroupList(
      groups: groups,
      pageSize: pageSize,
      expansion: expansion,
      // The group card's own margin from the screen edge, matching the
      // ungrouped Home list's own gutter (EventShortCard's default self-inset)
      // — separate from the 16px override below, which lines a card's text
      // up with the group header's.
      horizontalInset: 15,
      // EventShortCard has no top margin and 10 below, so this puts 16 above
      // the first card and below the last, as in mobo Billing's groups.
      bodyPadding: const EdgeInsets.only(top: 16, bottom: 6),
      // Room for the last group to scroll clear of the floating buttons.
      padding: EdgeInsets.only(bottom: bottomPadding),
      constrainInLandscape: true,
      itemNoun: 'event',
      itemNounPlural: 'events',
      itemBuilder: (context, event) => EventShortCard(
        key: ValueKey(event.id),
        eventShortDetails: event,
        // 16, not the 15 it defaults to outside a group: lines up with the
        // group header's own 16px padding (`_GroupHeader`).
        padding: const EdgeInsets.only(left: 16, right: 16),
      ),
    );
  }
}
