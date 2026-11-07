import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_layout.dart';

/// Full-screen "module not installed / missing" state (CLAUDE.md §20).
///
/// Semantic colour is orange for a missing module and red for a generic
/// "something went wrong", both pulled from [StatusColors] (§1).
class ModuleMissingError extends StatelessWidget {
  final String errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onContactAdmin;

  const ModuleMissingError({
    super.key,
    required this.errorMessage,
    this.onRetry,
    this.onContactAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMissingModule =
        errorMessage.contains('Missing Module') ||
        errorMessage.contains('Required App') ||
        errorMessage.contains('not installed');

    // §20 — orange for "module not installed", red for a plain error.
    final accent = isMissingModule ? StatusColors.orange : StatusColors.red;

    // A phone in landscape is ~300–400dp tall: the medallion, gaps and padding
    // shrink, and the single column scrolls if it still doesn't fit.
    final short = context.isShortScreen;

    // Animated icon medallion — the screen's single hero element (§21).
    final medallion = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        width: short ? 88 : 120,
        height: short ? 88 : 120,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isMissingModule ? Icons.extension_off_rounded : Icons.error_outline,
          size: short ? 44 : 60,
          color: accent,
        ),
      ),
    );

    final title = Text(
      isMissingModule ? 'Module Not Installed' : 'Error',
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
      textAlign: TextAlign.center,
    );

    final messageCard = Container(
      padding: EdgeInsets.all(short ? 16 : 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: accent.withValues(alpha: 0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            errorMessage,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            textAlign: TextAlign.center,
          ),

          if (isMissingModule) ...[
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
                      'Your administrator needs to install the required '
                      'Odoo app/module on the server.',
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

    // Actions — larger padding than §5 because this is a full-screen state.
    final actions = Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        if (onRetry != null)
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        if (onContactAdmin != null)
          ElevatedButton.icon(
            onPressed: onContactAdmin,
            icon: const Icon(Icons.support_agent),
            label: const Text('Contact Admin'),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: accent,
              foregroundColor: AppTheme.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
      ],
    );

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(short ? 16 : 24),
        // Width-capped and centred, so the message card doesn't stretch across
        // a 700–900dp landscape window.
        child: ConstrainedContent(
          maxWidth: 560,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              medallion,
              SizedBox(height: short ? 16 : 32),
              title,
              SizedBox(height: short ? 12 : 24),
              messageCard,
              SizedBox(height: short ? 16 : 32),
              actions,
            ],
          ),
        ),
      ),
    );
  }
}
