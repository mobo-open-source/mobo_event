import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart' show HugeIcon, HugeIcons;
import 'package:mobo_event/core/const/app_colors.dart';
import 'package:mobo_event/features/registration/provider/registration_provider.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/active_filter/activated_filter_list.dart';

class SearchFilter extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  const SearchFilter({super.key,required this.controller,required this.focusNode});

  @override
  State<SearchFilter> createState() => _SearchFilterState();
}

class _SearchFilterState extends State<SearchFilter> {

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RegistrationProvider>(context, listen: false);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 10,
                      offset: const Offset(4, 4),
                      spreadRadius: 2
                  ),

                ]
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              onChanged: (value) async {
                final provider = Provider.of<RegistrationProvider>(
                  context,
                  listen: false,
                );
                await provider.loadAttendees(reset: true, search: value);
              },
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: 'Search Attendees...',
                border: InputBorder.none,
                prefixIconConstraints: const BoxConstraints(minWidth: 45),

                prefixIcon: InkWell(
                  child:Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child:  HugeIcon(
                      icon: HugeIcons.strokeRoundedFilterHorizontal,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  onTap: () => _openFilter(context, provider),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openFilter(BuildContext context, RegistrationProvider provider) async {
    List<String> temporary = List.from(provider.activeFiltersByTotal);

    await showModalBottomSheet(
      backgroundColor: Colors.white,
      isScrollControlled: true,
      context: context,
      constraints: BoxConstraints(
        minWidth: MediaQuery.of(context).size.width,
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Filter",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedCancel01,
                        ),
                      ),
                    ],
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          if (temporary.isNotEmpty) ...[
                            const Text(
                              "Active Filters",
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ActivatedFilterList(
                              activeList: temporary,
                              onRemove: (value) {
                                setState(() {
                                  temporary.remove(value);
                                });
                              },
                            ),

                            const SizedBox(height: 20),
                          ],
                          Text(
                            "Event Type",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                            provider.eventTypeByEvents.map((single) {
                              return _statusChip(
                                label: single,
                                selected:
                                temporary.contains(single),
                                onTap: () {
                                  setState(() {
                                    if (temporary
                                        .contains(single)) {
                                      temporary.remove(single);
                                    } else {
                                      temporary.add(single);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          SizedBox(height: 20,),
                          Text(
                            "Registration state",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 10),

                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: provider.completeFiltersTotal.map((
                              single,
                            ) {
                              return _statusChip(
                                label: single,
                                selected: temporary.contains(single),
                                onTap: () {
                                  setState(() {
                                    if (temporary.contains(single)) {
                                      temporary.remove(single);
                                    } else {
                                      temporary.add(single);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size(120, 40),
                        
                            side: BorderSide(
                              color: primaryColor,
                              width: 1,
                            ),
                        
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                        
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        
                          onPressed: () async {
                        
                            setState(() {
                              temporary.clear();
                            });
                            provider
                                .setActiveFiltersTotal(
                                temporary);
                        
                            Navigator.pop(context);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              FocusScope.of(context).requestFocus(FocusNode());
                            });
                            await provider.loadAttendees(reset: true);
                          },
                          child: const Text("Clear All",style: TextStyle(
                            color: primaryColor
                          ),),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(120, 40),

                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),

                          onPressed: () async {
                            provider
                                .setActiveFiltersTotal(
                                temporary);
                            Navigator.pop(context);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              FocusScope.of(context).requestFocus(FocusNode());
                            });
                            await provider
                                .loadAttendees(reset: true);

                          },
                          child: const Text(
                            "Apply",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

Widget _statusChip({
  required String label,
  required bool selected,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: selected ? primaryColor : primaryColor.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          selected ? const Icon(Icons.check, size: 18,color: Colors.white,) : SizedBox.shrink(),

          const SizedBox(width: 5),
          Text(
            label,
            style:  TextStyle(
              color:selected ? Colors.white: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    ),
  );
}
