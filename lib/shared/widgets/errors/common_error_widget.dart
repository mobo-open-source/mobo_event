import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_layout.dart';
import '../empty_state.dart';

/// Common error widget with Lottie animation for better UX
/// Can be used across the app for consistent error display
class CommonErrorWidget extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onContactSupport;
  final ErrorType errorType;

  const CommonErrorWidget({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.onContactSupport,
    this.errorType = ErrorType.general,
  });

  /// Factory for module not installed error
  factory CommonErrorWidget.moduleNotInstalled({
    required String moduleName,
    String? customMessage,
    VoidCallback? onRetry,
    VoidCallback? onContactSupport,
  }) {
    return CommonErrorWidget(
      title: 'Module Not Installed',
      message:
          customMessage ??
          'The $moduleName module is not installed on your Odoo server. '
              'This feature requires the module to be installed by your administrator.',
      errorType: ErrorType.moduleNotInstalled,
      onRetry: onRetry,
      onContactSupport: onContactSupport,
    );
  }

  /// Factory for network error
  factory CommonErrorWidget.networkError({
    String? customMessage,
    VoidCallback? onRetry,
  }) {
    return CommonErrorWidget(
      title: 'No Connection',
      message:
          customMessage ??
          'Unable to connect to the server. Please check your internet connection and try again.',
      errorType: ErrorType.network,
      onRetry: onRetry,
    );
  }

  /// Factory for server error
  factory CommonErrorWidget.serverError({
    String? customMessage,
    VoidCallback? onRetry,
  }) {
    return CommonErrorWidget(
      title: 'Server Error',
      message:
          customMessage ??
          'Something went wrong on the server. Please try again later.',
      errorType: ErrorType.server,
      onRetry: onRetry,
    );
  }

  /// Factory for no data error
  factory CommonErrorWidget.noData({
    String? customMessage,
    VoidCallback? onRetry,
  }) {
    return CommonErrorWidget(
      title: 'No Data',
      message: customMessage ?? 'No data available at the moment.',
      errorType: ErrorType.noData,
      onRetry: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (errorType == ErrorType.noData) {
      return EmptyState(
        title: title,
        subtitle: message,
        // This returns a URL, EmptyState expects an asset path or we need to update EmptyState to support URLs or handle this.
        lottieAsset: _getAnimationUrl(),
      );
    }

    final theme = Theme.of(context);
    final config = _getErrorConfig();

    // A phone in landscape is ~300–400dp tall: the animation, gaps and padding
    // shrink, and the single column scrolls if it still doesn't fit.
    final short = context.isShortScreen;

    final animation = SizedBox(
      width: short ? 96 : 200,
      height: short ? 96 : 200,
      child: _buildAnimation(),
    );

    final titleText = Text(
      title,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
      textAlign: TextAlign.center,
    );

    final messageCard = Container(
      padding: EdgeInsets.all(short ? 16 : 20),
      decoration: BoxDecoration(
        color: config.backgroundColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: config.borderColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (config.showInfoBox) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: StatusColors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 20,
                    color: StatusColors.blue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      config.infoText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: StatusColors.blue,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    final actions = Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        if (onRetry != null)
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 20),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: config.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              side: BorderSide(color: config.primaryColor, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        if (onContactSupport != null)
          ElevatedButton.icon(
            onPressed: onContactSupport,
            icon: const Icon(Icons.support_agent, size: 20),
            label: const Text('Contact Support'),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              backgroundColor: config.primaryColor,
              foregroundColor: AppTheme.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
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
              SizedBox(height: short ? 12 : 24),
              titleText,
              SizedBox(height: short ? 12 : 16),
              messageCard,
              SizedBox(height: short ? 16 : 32),
              actions,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimation() {
    final animationUrl = _getAnimationUrl();

    return Lottie.network(
      animationUrl,
      fit: BoxFit.contain,
      repeat: true,
      errorBuilder: (context, error, stackTrace) {
        final config = _getErrorConfig();

        // §20 — icon medallion fallback when the animation can't load.
        return Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: config.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              config.fallbackIcon,
              size: 60,
              color: config.primaryColor,
            ),
          ),
        );
      },
    );
  }

  String _getAnimationUrl() {
    switch (errorType) {
      case ErrorType.moduleNotInstalled:
        return 'https://lottie.host/b8c0e0c5-9a5a-4f3e-8b5e-5c5e5e5e5e5e/5e5e5e5e5e.json'; // Plugin/Extension animation
      case ErrorType.network:
        return 'https://lottie.host/647eb023-6040-4b60-a275-e09b8f6f4c1f/kGzWWLWD0J.json'; // No connection animation
      case ErrorType.server:
        return 'https://lottie.host/4b3b3b3b-3b3b-3b3b-3b3b-3b3b3b3b3b3b/3b3b3b3b3b.json'; // Server error animation
      case ErrorType.noData:
        return 'https://lottie.host/2c2c2c2c-2c2c-2c2c-2c2c-2c2c2c2c2c2c/2c2c2c2c2c.json'; // Empty state animation
      case ErrorType.general:
      default:
        return 'https://lottie.host/1a1a1a1a-1a1a-1a1a-1a1a-1a1a1a1a1a1a/1a1a1a1a1a.json'; // General error animation
    }
  }

  _ErrorConfig _getErrorConfig() {
    switch (errorType) {
      case ErrorType.moduleNotInstalled:
        return _ErrorConfig(
          primaryColor: StatusColors.orange,
          backgroundColor: StatusColors.orange,
          borderColor: StatusColors.orange,
          fallbackIcon: Icons.extension_off_rounded,
          showInfoBox: true,
          infoText:
              'Contact your administrator to install the required module.',
        );
      case ErrorType.network:
        return _ErrorConfig(
          primaryColor: StatusColors.blue,
          backgroundColor: StatusColors.blue,
          borderColor: StatusColors.blue,
          fallbackIcon: Icons.wifi_off_rounded,
          showInfoBox: false,
          infoText: '',
        );
      case ErrorType.server:
        return _ErrorConfig(
          primaryColor: StatusColors.red,
          backgroundColor: StatusColors.red,
          borderColor: StatusColors.red,
          fallbackIcon: Icons.cloud_off_rounded,
          showInfoBox: false,
          infoText: '',
        );
      case ErrorType.noData:
        return _ErrorConfig(
          primaryColor: StatusColors.grey,
          backgroundColor: StatusColors.grey,
          borderColor: StatusColors.grey,
          fallbackIcon: Icons.inbox_rounded,
          showInfoBox: false,
          infoText: '',
        );
      case ErrorType.general:
      default:
        return _ErrorConfig(
          primaryColor: StatusColors.red,
          backgroundColor: StatusColors.red,
          borderColor: StatusColors.red,
          fallbackIcon: Icons.error_outline_rounded,
          showInfoBox: false,
          infoText: '',
        );
    }
  }
}

enum ErrorType { moduleNotInstalled, network, server, noData, general }

class _ErrorConfig {
  final Color primaryColor;
  final Color backgroundColor;
  final Color borderColor;
  final IconData fallbackIcon;
  final bool showInfoBox;
  final String infoText;

  _ErrorConfig({
    required this.primaryColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.fallbackIcon,
    required this.showInfoBox,
    required this.infoText,
  });
}
