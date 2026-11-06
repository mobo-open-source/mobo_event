import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/screen_layout.dart';

class SearchableTimezoneDropdown extends StatefulWidget {
  final List<String> timezones;
  final String? value;
  final ValueChanged<String> onChanged;

  const SearchableTimezoneDropdown({
    super.key,
    required this.timezones,
    required this.onChanged,
    this.value,
  });

  @override
  State<SearchableTimezoneDropdown> createState() =>
      _SearchableTimezoneDropdownState();
}

class _SearchableTimezoneDropdownState
    extends State<SearchableTimezoneDropdown> {
  String? selectedTimezone;

  @override
  void initState() {
    super.initState();
    selectedTimezone = widget.value;
  }

  void _openSearchSheet() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showModalBottomSheet<String>(
      // §19 — the sheet itself is transparent; the inner Container supplies
      // the background and the top-only rounding.
      backgroundColor: Colors.transparent,
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.grey[50],
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg),
            ),
          ),
          clipBehavior: Clip.hardEdge,
          child: _TimezoneSearchSheet(
            timezones: widget.timezones,
            selected: selectedTimezone,
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        selectedTimezone = result;
      });
      widget.onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _openSearchSheet,
      child: InputDecorator(
        decoration: InputDecoration(
          hintText: "Search your TimeZone",
          filled: true,
          fillColor: AppTheme.inputFill(isDark),

          hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: AppTheme.restingBorderSide(isDark),
          ),
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          selectedTimezone ?? 'Select Timezone',
          style: TextStyle(
            color: selectedTimezone == null
                ? Colors.grey
                : (isDark ? Colors.white : Colors.black),
          ),
        ),
      ),
    );
  }
}

class _TimezoneSearchSheet extends StatefulWidget {
  final List<String> timezones;
  final String? selected;

  const _TimezoneSearchSheet({required this.timezones, this.selected});

  @override
  State<_TimezoneSearchSheet> createState() => _TimezoneSearchSheetState();
}

class _TimezoneSearchSheetState extends State<_TimezoneSearchSheet> {
  late List<String> filteredList;
  final TextEditingController controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredList = widget.timezones;
  }

  void _filter(String query) {
    setState(() {
      filteredList = widget.timezones
          .where((tz) => tz.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Half the window upright. On its side that leaves ~150dp, too little
    // for the search box plus a usable list, so it takes nearly all of it.
    // Either way it is held to what is left above the keyboard (the padding
    // below), so the list shrinks and scrolls instead of overflowing.
    final media = MediaQuery.of(context);
    final short = context.isShortScreen;
    final available = media.size.height - media.viewInsets.bottom;
    final sheetHeight = math.min(
      media.size.height * (short ? 0.9 : 0.5),
      available,
    );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SizedBox(
          height: sheetHeight,
          child: Column(
            children: [
              SizedBox(height: short ? 12 : 30),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: controller,
                  onChanged: _filter,
                  decoration: InputDecoration(
                    hintText: "Search your TimeZone",
                    filled: true,
                    fillColor: AppTheme.inputFill(isDark),

                    hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: AppTheme.restingBorderSide(isDark),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final tz = filteredList[index];
                    final isSelected = tz == widget.selected;

                    return ListTile(
                      title: Text(tz),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: StatusColors.green)
                          : null,
                      onTap: () {
                        Navigator.pop(context, tz);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
