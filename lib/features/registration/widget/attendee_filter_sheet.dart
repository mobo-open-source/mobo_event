import 'package:flutter/material.dart';
import 'package:mobo_event/core/const/app_colors.dart';

import '../../../shared/widgets/active_filter/activated_filter_list.dart';
import '../../../shared/widgets/active_filter/filter_option_chip.dart';
import '../../../shared/widgets/filters/filter_group_by_sheet.dart';
import '../model/attendee_group.dart';

/// The attendees "Filter & Group By" bottom sheet, shared by the all-attendees
/// list ([SearchFilter]) and the per-event list ([AttendeeSearchEvent]) — which
/// differ only in the registration-state options, the Group By options and what
/// Clear All / Apply write to the provider and reload. The sheet itself —
/// tabs, radio rows, footer, sizing — is [showFilterGroupBySheet], shared with
/// the events list.
///
/// * [onCommit] receives the chosen filters and grouping when either button is
///   pressed (Clear All passes an empty list and no grouping) and stores them.
/// * [onClearReload] / [onApplyReload] then reload the list, after the sheet
///   has closed.
Future<void> showAttendeeFilterSheet(
  BuildContext context, {
  required List<String> initialFilters,
  required List<String> eventTypes,
  required List<String> stateFilters,
  required List<AttendeeGroupBy> groupByOptions,
  required AttendeeGroupBy? initialGroupBy,
  required void Function(List<String> filters, AttendeeGroupBy? groupBy)
  onCommit,
  required Future<void> Function() onClearReload,
  required Future<void> Function() onApplyReload,
}) {
  // What is ticked in the Filter tab — copied on open and only handed back by
  // Apply.
  final filters = List<String>.of(initialFilters);

  return showFilterGroupBySheet<AttendeeGroupBy>(
    context,
    groupByOptions: groupByOptions,
    initialGroupBy: initialGroupBy,
    filterTab: (context, short, rebuild) {
      Widget chips(List<String> options) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options
            .map(
              (single) => FilterOptionChip(
                label: single,
                selected: filters.contains(single),
                onTap: () {
                  if (!filters.remove(single)) filters.add(single);
                  rebuild();
                },
              ),
            )
            .toList(),
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (filters.isNotEmpty) ...[
            FilterSectionTitle(
              'Active Filters',
              color: primaryColor,
              top: short ? 8 : 16,
            ),
            ActivatedFilterList(
              activeList: filters,
              onRemove: (value) {
                filters.remove(value);
                rebuild();
              },
            ),
          ],
          FilterSectionTitle(
            'Event Type',
            top: filters.isEmpty ? (short ? 8 : 16) : 24,
          ),
          chips(eventTypes),
          const FilterSectionTitle('Registration state'),
          chips(stateFilters),
          const SizedBox(height: 12),
        ],
      );
    },
    onApply: (groupBy) async {
      onCommit(List.of(filters), groupBy);
      await onApplyReload();
    },
    onClear: () async {
      onCommit(const [], null);
      await onClearReload();
    },
  );
}
