import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobo_event/features/registration/provider/registration_provider.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/odoo_compat.dart';
import '../../../shared/widgets/forms/mobo_search_field.dart';
import '../model/attendee_group.dart';
import 'attendee_filter_sheet.dart';

/// Per-event attendees search bar — same toolbar as mobo_fleet's vehicles
/// list (`MoboSearchField`): a pill search field with a matching square
/// filter button beside it, both sharing one radius and shadow.
class AttendeeSearchEvent extends StatefulWidget {
  final TextEditingController controller;
  final int eventId;
  final FocusNode focusNode;

  /// Outer inset. Defaults to the list screen's side gutters; the landscape
  /// toolbar passes [EdgeInsets.zero] since it shares a row with other controls.
  final EdgeInsetsGeometry padding;

  const AttendeeSearchEvent({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.eventId,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  State<AttendeeSearchEvent> createState() => _AttendeeSearchEventState();
}

class _AttendeeSearchEventState extends State<AttendeeSearchEvent> {
  /// How long typing must pause before the search runs, so the list isn't
  /// refetched on every keystroke.
  static const _debounce = Duration(milliseconds: 500);

  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _search(String value) {
    _timer?.cancel();
    _timer = Timer(_debounce, () => _load(value));
  }

  void _searchNow(String value) {
    _timer?.cancel();
    _load(value);
  }

  /// The load rethrows; nothing awaits it, so swallow it here (the provider
  /// has already recorded the error).
  Future<void> _load(String value) async {
    try {
      await context.read<RegistrationProvider>().loadAttendeesByEvent(
        eventId: widget.eventId,
        reset: true,
        search: value,
      );
    } catch (_) {}
  }

  TextEditingController get controller => widget.controller;
  int get eventId => widget.eventId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: Consumer<RegistrationProvider>(
        builder: (context, provider, child) {
          return MoboSearchField(
            controller: controller,
            focusNode: widget.focusNode,
            hintText: 'Search Attendees...',
            hasActiveFilters:
                provider.activeFiltersByEvent.isNotEmpty ||
                provider.isGroupedEvent,
            onChanged: _search,
            onSubmitted: _searchNow,
            onClear: () => _searchNow(''),
            onFilterTap: () => _openFilter(context, provider),
          );
        },
      ),
    );
  }

  Future<void> _openFilter(
    BuildContext context,
    RegistrationProvider provider,
  ) async {
    final compat = await OdooCompat.current();
    if (!context.mounted) return;
    await showAttendeeFilterSheet(
      context,
      initialFilters: provider.activeFiltersByEvent,
      eventTypes: provider.eventTypeByEvents,
      stateFilters: provider.completeFiltersByEvents,
      // Every attendee here has the same event: it isn't offered.
      groupByOptions: AttendeeGroupBy.availableOn(compat, singleEvent: true),
      initialGroupBy: provider.groupByEvent,
      onCommit: (filters, groupBy) {
        // Both buttons reset the search text along with the filters.
        _timer?.cancel();
        controller.clear();
        provider.setActiveFiltersEvents(filters);
        provider.setGroupByEvent(groupBy);
      },
      onClearReload: () =>
          provider.loadAttendeesByEvent(reset: true, eventId: eventId),
      // From the first page: the filters or the grouping have changed what is
      // on it, and a grouped list has no pages to be left on.
      onApplyReload: () =>
          provider.loadAttendeesByEvent(reset: true, eventId: eventId),
    );
  }
}
