import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class RowInfo extends StatelessWidget {
  final List<List<dynamic>> icon;

  final String value;
  const RowInfo({super.key, required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HugeIcon(icon: icon, size: 15, color: Colors.grey.shade700),
        const SizedBox(width: 8),

        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.black87, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
