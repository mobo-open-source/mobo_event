import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../../core/theme/app_theme.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({
    super.key,
    this.message,
    this.color,
    this.size = 40,
    this.variant = LoadingVariant.staggeredDots,
    this.reduceMotion = false,
    this.overlay = false,
    this.barrierDismissible = false,
  });

  /// Optional message displayed under the loader (inline) or inside the card (overlay)
  final String? message;

  /// Custom color for the loader. Defaults to theme.primaryColor
  final Color? color;

  /// Size of the loader animation
  final double size;

  /// Select which loading animation to use
  final LoadingVariant variant;

  /// When true, shows a static icon instead of an animated loader to reduce motion
  final bool reduceMotion;

  /// When true, renders the loader as an overlay with a dimmed background and card
  final bool overlay;

  /// If [overlay] is true, whether tapping outside should dismiss. This only
  /// affects semantics; the widget itself does not pop routes. Keep false for blocking overlays.
  final bool barrierDismissible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final resolvedColor = color ?? theme.primaryColor;

    final loader = _buildLoader(resolvedColor, isDark);

    if (!overlay) return loader;

    return Stack(
      children: [
        Semantics(
          container: true,
          label: 'Loading overlay',
          child: ModalBarrier(
            dismissible: barrierDismissible,
            color: Colors.black.withValues(alpha: 0.2),
          ),
        ),
        Center(
          child: Card(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildAnimated(resolvedColor, isDark),
                  if (message != null && message!.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey[300] : Colors.black87,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoader(Color resolvedColor, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAnimated(resolvedColor, isDark),
          if (message != null && message!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.black87,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnimated(Color resolvedColor, bool isDark) {
    if (reduceMotion) {
      return Icon(Icons.hourglass_empty_rounded, color: resolvedColor, size: size);
    }

    switch (variant) {
      case LoadingVariant.fourRotatingDots:
        return LoadingAnimationWidget.fourRotatingDots(color: resolvedColor, size: size);
      case LoadingVariant.staggeredDots:
        return LoadingAnimationWidget.staggeredDotsWave(color: resolvedColor, size: size);
    }
  }
}

/// Supported animation variants for LoadingWidget
enum LoadingVariant {
  staggeredDots,
  fourRotatingDots,
}
