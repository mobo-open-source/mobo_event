import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class RowInfo extends StatelessWidget {
  final List<List<dynamic>> icon;

  final String value;
  const RowInfo({super.key, required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        HugeIcon(
          icon: icon,
          size: 15,
          color: isDark ? Colors.grey[400] : Colors.grey.shade700,
        ),
        const SizedBox(width: 8),

        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
