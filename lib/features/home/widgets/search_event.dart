import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobo_event/features/home/providers/home_provider.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/forms/mobo_search_field.dart';
import 'event_filter_sheet.dart';

/// Event list search bar — same toolbar as mobo_fleet's vehicles list
/// (`MoboSearchField`): a pill search field with a matching square filter
/// button beside it, both sharing one radius and shadow. The button opens the
/// Filter & Group By sheet ([showEventFilterSheet]).
class SearchEvent extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  /// Outer inset. Defaults to the Home screen's side gutters; the landscape
  /// toolbar passes [EdgeInsets.zero] since it shares a row with other controls.
  final EdgeInsetsGeometry padding;

  const SearchEvent({
    super.key,
    required this.controller,
    required this.focusNode,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  State<SearchEvent> createState() => _SearchEventState();
}

class _SearchEventState extends State<SearchEvent> {
  /// How long typing must pause before the search runs, so the list isn't
  /// refetched on every keystroke.
  static const _debounce = Duration(milliseconds: 500);

  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _search(HomeProvider provider, String value) {
    _timer?.cancel();
    _timer = Timer(_debounce, () => _load(provider, value));
  }

  void _searchNow(HomeProvider provider, String value) {
    _timer?.cancel();
    _load(provider, value);
  }

  /// Runs the search for [value], dropping any error.
  ///
  /// `loadEvents` rethrows; nothing awaits this, so swallow it here (the
  /// provider has already reset its loading state).
  Future<void> _load(HomeProvider provider, String value) async {
    try {
      await provider.loadEvents(search: value);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final focusNode = widget.focusNode;
    return Padding(
      padding: widget.padding,
      child: Consumer<HomeProvider>(
        builder: (context, provider, child) {
          return MoboSearchField(
            controller: controller,
            focusNode: focusNode,
            hintText: 'Search Events...',
            hasActiveFilters:
                provider.activeFilters.isNotEmpty || provider.isGrouped,
            onChanged: (value) => _search(provider, value),
            onSubmitted: (value) => _searchNow(provider, value),
            onClear: () => _searchNow(provider, ''),
            onFilterTap: () => showEventFilterSheet(
              context,
              searchController: controller,
              searchFocusNode: focusNode,
            ),
          );
        },
      ),
    );
  }
}
