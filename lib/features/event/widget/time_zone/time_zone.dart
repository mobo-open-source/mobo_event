import 'package:flutter/material.dart';

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
    final result = await showModalBottomSheet<String>(
      backgroundColor: Colors.white,
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _TimezoneSearchSheet(
          timezones: widget.timezones,
          selected: selectedTimezone,
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
    return GestureDetector(
      onTap: _openSearchSheet,
      child: InputDecorator(
        decoration:  InputDecoration(
          hintText: "Search your TimeZone",
          filled: true,
          fillColor: const Color(0xFFF1F3F5),

          hintStyle: TextStyle(
              color: Colors.grey,
              fontSize: 14
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          selectedTimezone ?? 'Select Timezone',
          style: TextStyle(
            color: selectedTimezone == null
                ? Colors.grey
                : Colors.black,
          ),
        ),
      ),
    );
  }
}
class _TimezoneSearchSheet extends StatefulWidget {
  final List<String> timezones;
  final String? selected;

  const _TimezoneSearchSheet({
    required this.timezones,
    this.selected,
  });

  @override
  State<_TimezoneSearchSheet> createState() =>
      _TimezoneSearchSheetState();
}

class _TimezoneSearchSheetState
    extends State<_TimezoneSearchSheet> {
  late List<String> filteredList;
  final TextEditingController controller =
  TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredList = widget.timezones;
  }

  void _filter(String query) {
    setState(() {
      filteredList = widget.timezones
          .where((tz) =>
          tz.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(

          height: MediaQuery.of(context).size.height * 0.5,
          child: Column(
            children: [
              const SizedBox(height: 30),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: controller,
                  onChanged: _filter,
                  decoration:  InputDecoration(
                    hintText: "Search your TimeZone",
                    filled: true,
                    fillColor: const Color(0xFFF1F3F5),

                    hintStyle: TextStyle(
                        color: Colors.grey,
                        fontSize: 14
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
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
                          ? const Icon(Icons.check,
                          color: Colors.green)
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
