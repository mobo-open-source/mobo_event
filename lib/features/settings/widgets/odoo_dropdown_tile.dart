import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Settings-only row style: the picker sits inline next to the title
/// instead of as a full-width field below the description — everything
/// else (icon, subtitle, "Last updated") stays exactly as it was. Not used
/// anywhere else in the app; every other picker still goes through
/// MoboSingleSelectField per the app's normal convention.
class OdooDropdownTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<List<dynamic>> icon;
  final String? selectedValue;
  final List<Map<String, dynamic>> options;
  final bool isLoading;
  final Function(String?) onChanged;
  final String displayKey;
  final String valueKey;
  final DateTime? lastUpdated;

  const OdooDropdownTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selectedValue,
    required this.options,
    required this.isLoading,
    required this.onChanged,
    required this.displayKey,
    required this.valueKey,
    this.lastUpdated,
  });

  String _formatLastUpdated(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Deduplicate + make sure the current value is always selectable, even
    // if the server hasn't returned it in `options` yet.
    final seenValues = <String>{};
    final List<Map<String, dynamic>> uniqueOptions = [];
    for (final opt in options) {
      final val = opt[valueKey]?.toString();
      if (val != null && val.isNotEmpty && seenValues.add(val)) {
        uniqueOptions.add(opt);
      }
    }
    final bool hasCurrent =
        selectedValue != null &&
        uniqueOptions.any(
          (option) => option[valueKey]?.toString() == selectedValue?.toString(),
        );
    final List<Map<String, dynamic>> effectiveOptions = [
      if (!hasCurrent && selectedValue != null && selectedValue!.isNotEmpty)
        {valueKey: selectedValue, displayKey: selectedValue},
      ...uniqueOptions,
    ];
    final String? currentValue =
        effectiveOptions.any(
          (option) => option[valueKey]?.toString() == selectedValue?.toString(),
        )
        ? selectedValue
        : null;

    final double triggerWidth = (MediaQuery.of(context).size.width * 0.34)
        .clamp(110.0, 160.0);
    final double popupMenuWidth = (MediaQuery.of(context).size.width * 0.75)
        .clamp(240.0, 320.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: icon,
            color: isDark ? Colors.grey[400] : Colors.black,
            size: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    (isLoading && options.isEmpty)
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : SizedBox(
                            width: triggerWidth,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                isDense: true,
                                value: currentValue,
                                onChanged: onChanged,
                                dropdownColor: isDark
                                    ? const Color(0xFF2C2C2C)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                menuMaxHeight: 320,
                                menuWidth: popupMenuWidth,
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[700],
                                ),
                                selectedItemBuilder: (context) {
                                  return effectiveOptions.map((option) {
                                    final String displayText =
                                        (option[displayKey] ??
                                                option[valueKey] ??
                                                '')
                                            .toString();
                                    return Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        displayText,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    );
                                  }).toList();
                                },
                                items: effectiveOptions.map((
                                  Map<String, dynamic> option,
                                ) {
                                  final String val = (option[valueKey] ?? '')
                                      .toString();
                                  final String displayText =
                                      (option[displayKey] ??
                                              option[valueKey] ??
                                              '')
                                          .toString();
                                  return DropdownMenuItem<String>(
                                    value: val,
                                    child: Text(
                                      displayText,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                if (lastUpdated != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Last updated • ${_formatLastUpdated(lastUpdated)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
