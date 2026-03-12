import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class StatusTabShimmer extends StatelessWidget {
  const StatusTabShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.black12),
        ),
        child: const SizedBox(
          width: 60,
          height: 14,
        ),
      ),
    );
  }
}
