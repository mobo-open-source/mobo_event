import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';

/// An Odoo record's image (`image_1920`, `image_128`, …) from its base64
/// value, with a placeholder when there is none. Handles SVG as well as
/// raster images — Odoo stores a generated SVG avatar for users who never
/// uploaded a photo.
class OdooAvatar extends StatelessWidget {
  final String? imageBase64;
  final double size;
  final double iconSize;
  final BoxFit fit;
  final Color? placeholderColor;
  final Color? iconColor;
  final BorderRadius? borderRadius;
  final dynamic fallbackIcon;

  const OdooAvatar({
    super.key,
    required this.imageBase64,
    this.size = 40.0,
    this.iconSize = 20.0,
    this.fit = BoxFit.cover,
    this.placeholderColor,
    this.iconColor,
    this.borderRadius,
    this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectivePlaceholderColor =
        placeholderColor ?? (isDark ? Colors.grey[700] : Colors.grey[100]);
    final effectiveIconColor =
        iconColor ?? (isDark ? Colors.grey[400] : Colors.grey[600]);

    Widget content;

    if (imageBase64 == null || imageBase64!.isEmpty || imageBase64 == 'false') {
      content = _buildPlaceholder(
        effectivePlaceholderColor!,
        effectiveIconColor!,
      );
    } else {
      try {
        final imageBytes = const Base64Decoder().convert(imageBase64!);

        bool isSvg = false;
        if (imageBytes.length > 10) {
          final head = utf8.decode(
            imageBytes.sublist(0, math.min(100, imageBytes.length)),
            allowMalformed: true,
          );
          if (head.contains('<svg')) {
            isSvg = true;
          }
        }

        if (isSvg) {
          content = SvgPicture.memory(
            imageBytes,
            width: size,
            height: size,
            fit: fit,
            placeholderBuilder: (context) => _buildPlaceholder(
              effectivePlaceholderColor!,
              effectiveIconColor!,
            ),
          );
        } else {
          content = Image.memory(
            imageBytes,
            width: size,
            height: size,
            fit: fit,
            // Keeps the previous photo on screen while a replacement decodes,
            // instead of blinking to the placeholder on every profile edit.
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(
              effectivePlaceholderColor!,
              effectiveIconColor!,
            ),
          );
        }
      } catch (_) {
        content = _buildPlaceholder(
          effectivePlaceholderColor!,
          effectiveIconColor!,
        );
      }
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: content);
    }
    return content;
  }

  Widget _buildPlaceholder(Color color, Color iconColor) {
    return Container(
      width: size,
      height: size,
      color: color,
      child: Center(
        child: HugeIcon(
          icon: fallbackIcon ?? HugeIcons.strokeRoundedUser,
          size: iconSize,
          color: iconColor,
        ),
      ),
    );
  }
}
