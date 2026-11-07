import 'package:flutter/material.dart';

class OptionWidget extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback? onTap;

  const OptionWidget({
    super.key,
    required this.title,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        // The tab row gives each pill a fixed height (40), taller than the
        // text and its padding. A padded Container puts its child at the top of
        // that space, which left the title ~2.5px above centre; this centres it.
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? Colors.white : Colors.black)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.black12,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isActive
                ? (isDark ? Colors.black : Colors.white)
                : (isDark ? Colors.white : Colors.black),
          ),
        ),
      ),
    );
  }
}
