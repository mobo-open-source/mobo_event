/// One group of a grouped list: what it is called, and what is in it.
///
/// Shared by every screen that offers a Group By — the events list and board
/// and the attendees lists — so they all feed the same [ExpandableGroupList].
/// A screen with something more to say about its groups (a record to write
/// when a card is dropped on one) subclasses it.
class GroupSection<T> {
  const GroupSection({
    required this.key,
    required this.label,
    required this.items,
  });

  /// Identifies the group across rebuilds — it carries the grouping field, so
  /// two groupings never share one. What the expand/collapse state hangs on.
  final String key;

  final String label;
  final List<T> items;
}
