import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/screen_layout.dart';

class ConnectionStatusWidget extends StatelessWidget {
  final bool serverUnreachable;
  final VoidCallback? onRetry;
  final String? customMessage;

  const ConnectionStatusWidget({
    super.key,
    this.serverUnreachable = false,
    this.onRetry,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // A phone in landscape is ~300–400dp tall: tighter padding and spacing so
    // the message and Retry button stay on screen.
    final short = context.isShortScreen;

    // Centred in the space it is given, and scrolls — rather than overflowing —
    // when that space is shorter than the content. With room to spare it looks
    // exactly as before.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(short ? 16 : 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: short ? 64 : 80,
                    height: short ? 64 : 80,
                    decoration: BoxDecoration(
                      color: isDark
                          ? StatusColors.red.withValues(alpha: 0.2)
                          : StatusColors.errorBackgroundLight,
                      shape: BoxShape.circle,
                    ),
                    child: HugeIcon(
                      icon: serverUnreachable
                          ? HugeIcons.strokeRoundedWifiDisconnected02
                          : HugeIcons.strokeRoundedAlert02,
                      size: short ? 32 : 40,
                      color: isDark ? StatusColors.errorIcon : StatusColors.red,
                    ),
                  ),
                  SizedBox(height: short ? 12 : 24),
                  Text(
                    serverUnreachable
                        ? 'Server Unreachable'
                        : 'Connection Error',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  SizedBox(height: short ? 8 : 12),
                  Text(
                    customMessage ??
                        (serverUnreachable
                            ? 'Unable to connect to the server.\nPlease check your internet connection.'
                            : 'Something went wrong.\nPlease try again.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                  if (onRetry != null) ...[
                    SizedBox(height: short ? 16 : 32),
                    ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh, size: 20),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
