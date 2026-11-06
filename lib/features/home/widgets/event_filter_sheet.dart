import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/const/app_colors.dart';
import '../../../shared/widgets/active_filter/activated_filter_list.dart';
import '../../../shared/widgets/active_filter/filter_option_chip.dart';
import '../../../shared/widgets/filters/filter_group_by_sheet.dart';
import '../model/event_group.dart';
import '../providers/home_provider.dart';

/// Opens the Home screen's "Filter & Group By" bottom sheet: the event
/// filters on one tab, the Group By choice on the other. The sheet itself —
/// tabs, radio rows, footer, sizing — is [showFilterGroupBySheet], shared with
/// the attendee lists; this supplies the event filters and what Apply writes.
///
/// Nothing the sheet changes reaches the provider until Apply (or Clear All),
/// so closing it any other way leaves the list as it was.
///
/// [searchController] / [searchFocusNode] belong to the search field the sheet
/// was opened from: applying a filter set restarts the search, as it always has.
Future<void> showEventFilterSheet(
  BuildContext context, {
  required TextEditingController searchController,
  required FocusNode searchFocusNode,
}) {
  final provider = context.read<HomeProvider>();

  // What is ticked in the Filter tab — copied from the provider on open and
  // only written back by Apply.
  final filters = List<String>.of(provider.activeFilters);

  // Grouping is done on the events already loaded, so only a change to the
  // filters (or a search that Apply/Clear All restarts) needs a fetch.
  bool needsReload(List<String> next) {
    final current = provider.activeFilters;
    final sameFilters =
        current.length == next.length && current.toSet().containsAll(next);
    return !sameFilters ||
        searchController.text.isNotEmpty ||
        provider.searchText.isNotEmpty;
  }

  Future<void> commit(List<String> next, EventGroupBy? groupBy) async {
    final reload = needsReload(next);
    searchController.clear();
    provider.setActiveFilters(next);
    provider.setGroupBy(groupBy);
    searchFocusNode.unfocus();
    if (reload) await provider.loadEvents();
  }

  return showFilterGroupBySheet<EventGroupBy>(
    context,
    groupByOptions: EventGroupBy.availableOn(provider.compat),
    initialGroupBy: provider.groupBy,
    // The board has stage columns when nothing else is chosen.
    noneDescription: provider.viewMode == HomeViewMode.kanban
        ? 'Show the default stage columns'
        : 'Display as a simple list',
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
          chips(provider.eventType),
          const FilterSectionTitle('Others'),
          chips(provider.fullFilters),
          const SizedBox(height: 12),
        ],
      );
    },
    onApply: (groupBy) => commit(filters, groupBy),
    onClear: () => commit(const [], null),
  );
}
