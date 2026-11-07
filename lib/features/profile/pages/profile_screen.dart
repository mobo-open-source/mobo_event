import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_event/features/profile/pages/profile_detail_screen.dart';
import 'package:mobo_event/features/profile/widgets/profile_header_card.dart';
import 'package:mobo_event/features/profile/widgets/switch_account_widget.dart';
import 'package:mobo_event/features/settings/pages/settings_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/logout_view_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_layout.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../providers/profile_provider.dart';

import '../../../shared/widgets/action_tile.dart';
import '../../../shared/widgets/connection_status_widget.dart';

/// A screen that provides a high-level overview of the user's profile and app configuration.
///
/// This screen serves as a central hub for accessing settings, switching accounts,
/// managing profile photos, and initiating logout.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().initialize();
    });
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 600,
      );
      if (picked == null || !mounted) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      final base64Image = base64Encode(bytes);
      await context.read<ProfileProvider>().updateProfileImage(base64Image);

      if (mounted) {
        CustomSnackbar.show(
          context: context,
          title: 'Success',
          message: 'Profile image updated successfully',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          title: 'Error',
          message: 'Failed to update image: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  void _showImageSourceActionSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      // Two short rows don't need an 800dp-wide sheet in landscape.
      constraints: context.isLandscape
          ? const BoxConstraints(maxWidth: 560)
          : null,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          InkWell(
            onTap: () {
              Navigator.pop(context);
              _pickImageFromSource(ImageSource.camera);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedCamera02,
                    size: 24,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  const SizedBox(width: 16),
                  const Text('Take Photo', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.grey[800] : Colors.grey[200],
          ),
          InkWell(
            onTap: () {
              Navigator.pop(context);
              _pickImageFromSource(ImageSource.gallery);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedImageCrop,
                    size: 24,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Choose from Gallery',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double rs(double size) {
      // Shortest side, not width, so a phone turned sideways keeps its
      // portrait text size instead of scaling up inside a shorter window.
      final w = MediaQuery.sizeOf(context).shortestSide;
      final scale = (w / 390.0).clamp(0.85, 1.2);
      return size * scale;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Configuration',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
            fontSize: rs(22),
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      ),
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      // Left/right insets (a notch or a gesture bar sits on the sides when the
      // phone is sideways) always apply; the bottom one only in landscape, so
      // portrait keeps its current edge-to-edge scrolling.
      body: SafeArea(
        top: false,
        bottom: context.isLandscape,
        child: Consumer<ProfileProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && provider.hasInternet) {
              return _buildLoadingShimmer(context, isDark);
            }

            if (provider.userData == null) {
              final error = ConnectionStatusWidget(
                serverUnreachable: true,
                onRetry: () => provider.fetchUserProfile(),
              );
              // The error card (~400dp) is taller than a landscape window, so
              // there it scrolls; with the room it keeps filling the screen
              // and sitting centred, exactly as before.
              return LayoutBuilder(
                builder: (context, constraints) => constraints.maxHeight < 480
                    ? SingleChildScrollView(child: error)
                    : error,
              );
            }

            final header = ProfileHeaderCard(
              name: provider.userData!['name']?.toString() ?? 'Unknown User',
              email: provider.normalizeForEdit(provider.userData!['email']),
              jobFunction: provider.normalizeForEdit(
                provider.userData!['function'],
              ),
              avatarBase64: provider.userAvatarBase64,
              onCameraPressed: _showImageSourceActionSheet,
              showCameraButton: false,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileDetailScreen(),
                  ),
                );
              },
            );

            return RefreshIndicator(
              onRefresh: () => provider.fetchUserProfile(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                // One scrolling column in every orientation; in landscape it
                // is capped and centred rather than stretched across the
                // whole width. Portrait keeps the full width.
                child: ConstrainedContent(
                  maxWidth: context.isLandscape ? 600 : double.infinity,
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        header,
                        const SizedBox(height: 12),

                        _buildQuickActionsSection(context),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      // Clipped, with a transparent Material below, so the rows' ripples show
      // over the card's fill and stay inside its corners (an InkWell under an
      // opaque Container paints beneath it).
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // grey[850] over the page's grey[900] in dark mode, as mobo Billing's
        // Configuration list. It was the page's own colour, so the list had no
        // edge there and read as bare rows on the background.
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppTheme.cardBorder(isDark), width: 0.5),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            ActionTile(
              title: 'Settings',
              subtitle: 'App preferences and sync options',
              icon: HugeIcons.strokeRoundedSettings01,
              onTap: () async {
                try {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SettingsScreen()),
                  );
                } catch (_) {}
              },
            ),
            Divider(
              height: 1,
              color: isDark ? Colors.grey[800] : Colors.grey[200],
            ),
            const SwitchAccountWidget(),
            Divider(
              height: 1,
              color: isDark ? Colors.grey[800] : Colors.grey[200],
            ),

            Builder(
              builder: (outerCtx) => ChangeNotifierProvider<LogoutViewModel>(
                create: (_) => LogoutViewModel(),
                child: Builder(
                  builder: (ctx) => ActionTile(
                    title: 'Logout',
                    subtitle: 'Sign out from this device',
                    icon: HugeIcons.strokeRoundedLogout01,
                    // The brand colour on the icon and title, so the one row
                    // that ends the session stands out from the rest.
                    accentColor: AppTheme.primaryColor,
                    trailing: const SizedBox.shrink(),
                    onTap: () => ctx.read<LogoutViewModel>().confirmLogout(ctx),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer(BuildContext context, bool isDark) {
    final shimmerBase = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final shimmerHighlight = isDark ? Colors.grey[700]! : Colors.grey[100]!;
    final placeholderColor = isDark ? Colors.grey[900]! : Colors.white;
    final cardColor = isDark ? Colors.grey[900] : Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ConstrainedContent(
        // Capped in landscape only; portrait keeps the full width.
        maxWidth: context.isLandscape ? 600 : double.infinity,
        child: Shimmer.fromColors(
          baseColor: shimmerBase,
          highlightColor: shimmerHighlight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 16,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: placeholderColor,
                        border: Border.all(
                          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                          width: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 18,
                            width: 180,
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: placeholderColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          Container(
                            height: 14,
                            width: 160,
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: placeholderColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          Container(
                            height: 12,
                            width: 120,
                            decoration: BoxDecoration(
                              color: placeholderColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.06),
                  ),
                ),
                child: Column(
                  children: List.generate(2, (index) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: index == 1 ? 0 : 16),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: placeholderColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 14,
                                  width: 120,
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(
                                    color: placeholderColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                Container(
                                  height: 12,
                                  width: 180,
                                  decoration: BoxDecoration(
                                    color: placeholderColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
