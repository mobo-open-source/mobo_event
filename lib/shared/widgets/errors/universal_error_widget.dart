import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../core/services/error_manager.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_layout.dart';

/// Universal error display widget that uses ErrorManager for consistent error handling
class UniversalErrorWidget extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  final VoidCallback? onContactSupport;

  const UniversalErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.onContactSupport,
  });

  @override
  Widget build(BuildContext context) {
    final errorInfo = ErrorManager.analyzeError(error);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // A phone in landscape is ~300–400dp tall: the animation, gaps and padding
    // shrink, and the single column scrolls if it still doesn't fit.
    final short = context.isShortScreen;

    final animation = SizedBox(
      width: short ? 120 : 260,
      height: short ? 120 : 260,
      child: _buildAnimation(errorInfo),
    );

    final title = Text(
      errorInfo.title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimaryOn(isDark),
      ),
      textAlign: TextAlign.center,
    );

    // Message — Odoo's own wording, plain text under the title.
    final message = Text(
      errorInfo.message,
      style: TextStyle(
        fontSize: 14,
        height: 1.4,
        color: AppTheme.secondaryLabelColor(isDark),
      ),
      textAlign: TextAlign.center,
    );

    final actions = Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        if (onRetry != null)
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        if (onContactSupport != null ||
            errorInfo.type == ErrorType.moduleNotInstalled)
          ElevatedButton(
            onPressed: onContactSupport ?? () {},
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text(
              'Contact Admin',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(short ? 16 : 24.0),
        // Width-capped and centred, so the message doesn't stretch across a
        // 700–900dp landscape window.
        child: ConstrainedContent(
          maxWidth: 560,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              animation,
              SizedBox(height: short ? 8 : 16),
              title,
              SizedBox(height: short ? 6 : 8),
              message,
              SizedBox(height: short ? 16 : 24),
              actions,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimation(ErrorInfo errorInfo) {
    // Server and network errors get the bundled Lottie; anything else, or a
    // Lottie that fails to load, falls back to the icon.
    if (errorInfo.type == ErrorType.server ||
        errorInfo.type == ErrorType.network) {
      return Lottie.asset(
        'assets/lotties/Error 404.json',
        fit: BoxFit.contain,
        repeat: true,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackIcon(errorInfo);
        },
      );
    }

    return _buildFallbackIcon(errorInfo);
  }

  Widget _buildFallbackIcon(ErrorInfo errorInfo) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: errorInfo.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(errorInfo.icon, size: 60, color: errorInfo.color),
          ),
        );
      },
    );
  }
}

/// [UniversalErrorWidget] filling the space it is given and scrolling, so
/// pulling down inside a `RefreshIndicator` retries just as the button does.
class ScrollableErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const ScrollableErrorView({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: constraints.maxHeight,
            child: UniversalErrorWidget(error: error, onRetry: onRetry),
          ),
        ],
      ),
    );
  }
}
