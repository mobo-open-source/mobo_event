import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class InfoRow extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final String value;

  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HugeIcon(icon: icon, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 8),

        Text(label),

        Spacer(),

        Expanded(
          child: Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w600),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
