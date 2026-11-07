import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobo_event/features/registration/provider/registration_provider.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/forms/mobo_search_field.dart';
import '../../../core/utils/odoo_compat.dart';
import '../model/attendee_group.dart';
import 'attendee_filter_sheet.dart';

/// Attendees list search bar — same toolbar as mobo_fleet's vehicles list
/// (`MoboSearchField`): a pill search field with a matching square filter
/// button beside it, both sharing one radius and shadow.
class SearchFilter extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  /// Outer inset. Defaults to the list screen's side gutters; the landscape
  /// toolbar passes [EdgeInsets.zero] since it shares a row with other controls.
  final EdgeInsetsGeometry padding;

  const SearchFilter({
    super.key,
    required this.controller,
    required this.focusNode,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  State<SearchFilter> createState() => _SearchFilterState();
}

class _SearchFilterState extends State<SearchFilter> {
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
      await context.read<RegistrationProvider>().loadAttendees(
        reset: true,
        search: value,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: Consumer<RegistrationProvider>(
        builder: (context, provider, child) {
          return MoboSearchField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            hintText: 'Search Attendees...',
            hasActiveFilters:
                provider.activeFiltersByTotal.isNotEmpty ||
                provider.isGroupedTotal,
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
      initialFilters: provider.activeFiltersByTotal,
      eventTypes: provider.eventTypeByEvents,
      stateFilters: provider.completeFiltersTotal,
      groupByOptions: AttendeeGroupBy.availableOn(compat, singleEvent: false),
      initialGroupBy: provider.groupByTotal,
      onCommit: (filters, groupBy) {
        provider.setActiveFiltersTotal(filters);
        provider.setGroupByTotal(groupBy);
      },
      onClearReload: () => provider.loadAttendees(reset: true),
      onApplyReload: () => provider.loadAttendees(reset: true),
    );
  }
}
