import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/utils/screen_layout.dart';
import '../../../shared/widgets/section_card.dart';
import '../widgets/switch_tile.dart';
import '../widgets/odoo_dropdown_tile.dart';
import '../../../shared/widgets/action_tile.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';

/// Settings screen for managing app-wide preferences.
///
/// Sections:
///   • Appearance — dark mode toggle
///   • Security — biometric app lock
///   • Language & Region — language, currency, timezone dropdowns
///   • Help & Support — links to Odoo documentation and support
///   • About — company links, social media, copyright
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isBiometricEnabled = false;
  bool _isBiometricAvailable = false;
  String _authStatusDescription = 'Checking authentication status...';

  @override
  void initState() {
    super.initState();
    _initializeSettings();
    _loadBiometricSettings();
  }

  Future<void> _initializeSettings() async {
    final settingsProvider = context.read<SettingsProvider>();
    await settingsProvider.initialize();
  }

  Future<void> _loadBiometricSettings() async {
    try {
      final isEnabled = await BiometricService.isBiometricEnabled();
      final isAvailable = await BiometricService.isBiometricAvailable();
      final description = isAvailable
          ? (isEnabled
                ? 'Biometric authentication is enabled'
                : 'Biometric authentication is available but disabled')
          : 'Biometric authentication is not available on this device';

      if (mounted) {
        setState(() {
          _isBiometricEnabled = isEnabled;
          _isBiometricAvailable = isAvailable;
          _authStatusDescription = description;
        });
      }
    } catch (_) {
      // Biometric check is non-critical; defaults will remain.
    }
  }

  Future<void> _toggleBiometric(bool enabled) async {
    try {
      if (enabled) {
        final canAuthenticate =
            await BiometricService.authenticateWithBiometrics(
              reason: 'Authenticate to enable biometric login',
            );
        if (!canAuthenticate) {
          if (mounted) {
            CustomSnackbar.showError(
              context,
              'Authentication failed. Biometric authentication not enabled.',
            );
          }
          return;
        }
      }

      await BiometricService.setBiometricEnabled(enabled);
      await _loadBiometricSettings();

      if (mounted) {
        if (enabled) {
          CustomSnackbar.showSuccess(
            context,
            'Biometric authentication enabled successfully',
          );
        } else {
          CustomSnackbar.showInfo(context, 'Biometric authentication disabled');
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(
          context,
          'Failed to ${enabled ? 'enable' : 'disable'} biometric authentication: $e',
        );
      }
    }
  }

  Widget _buildAboutContent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    // The tiles carry their own 16px inset, like the Appearance and Language
    // tiles; only the divider, socials and copyright below them get one here.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ActionTile(
            title: 'Visit Website',
            subtitle: 'www.cybrosys.com',
            icon: HugeIcons.strokeRoundedGlobe02,
            onTap: () => _launchUrlSmart(
              'https://www.cybrosys.com/',
              title: 'Our Website',
            ),
          ),
          ActionTile(
            title: 'Contact Us',
            subtitle: 'info@cybrosys.com',
            icon: HugeIcons.strokeRoundedMail01,
            onTap: () => _launchUrlSmart('mailto:info@cybrosys.com'),
          ),

          if (Theme.of(context).platform == TargetPlatform.android)
            ActionTile(
              title: 'More Apps',
              subtitle: 'View our other apps on Play Store',
              icon: HugeIcons.strokeRoundedPlayStore,
              onTap: () => _launchUrlSmart(
                'https://play.google.com/store/apps/dev?id=7163004064816759344&pli=1',
                title: 'Play Store',
              ),
            ),
          if (Theme.of(context).platform == TargetPlatform.iOS)
            ActionTile(
              title: 'More Apps',
              subtitle: 'View our other apps on App Store',
              icon: HugeIcons.strokeRoundedAppStore,
              onTap: () => _launchUrlSmart(
                'https://apps.apple.com/in/developer/cybrosys-technologies/id1805306445',
                title: 'App Store',
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Divider(color: isDark ? Colors.grey[800] : Colors.grey[200]),
                const SizedBox(height: 16),

                Center(
                  child: Text(
                    'Follow Us',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSocialButton(
                      context,
                      'assets/images/social/facebook.png',
                      const Color(0xFF1877F2),
                      'Facebook',
                      () => _launchUrlSmart(
                        'https://www.facebook.com/cybrosystechnologies',
                        title: 'Facebook',
                      ),
                    ),
                    _buildSocialButton(
                      context,
                      'assets/images/social/linkedin.png',
                      const Color(0xFF0077B5),
                      'LinkedIn',
                      () => _launchUrlSmart(
                        'https://www.linkedin.com/company/cybrosys/',
                        title: 'LinkedIn',
                      ),
                    ),
                    _buildSocialButton(
                      context,
                      'assets/images/social/instagram.png',
                      const Color(0xFFE4405F),
                      'Instagram',
                      () => _launchUrlSmart(
                        'https://www.instagram.com/cybrosystech/',
                        title: 'Instagram',
                      ),
                    ),
                    _buildSocialButton(
                      context,
                      'assets/images/social/youtube.png',
                      const Color(0xFFFF0000),
                      'YouTube',
                      () => _launchUrlSmart(
                        'https://www.youtube.com/channel/UCKjWLm7iCyOYINVspCSanjg',
                        title: 'YouTube',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                Center(
                  child: Text(
                    '© ${DateTime.now().year} Cybrosys Technologies',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrlSmart(String url, {String? title}) async {
    final uri = Uri.parse(url);
    try {
      final isWeb = uri.scheme == 'http' || uri.scheme == 'https';
      final mode = isWeb
          ? LaunchMode.inAppBrowserView
          : LaunchMode.externalApplication;

      final ok = await launchUrl(uri, mode: mode);
      if (!ok) {
        if (!mounted) return;
        CustomSnackbar.showError(
          context,
          'No app available to open this link.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(context, 'Could not open link. ${e.toString()}');
    }
  }

  Widget _buildSocialButton(
    BuildContext context,
    String imagePath,
    Color underlineColor,
    String label,
    VoidCallback onPressed,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 46,
            height: 46,
            padding: const EdgeInsets.all(12),
            child: Image.asset(
              imagePath,
              width: 24,
              height: 24,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 48,
          height: 3,
          decoration: BoxDecoration(
            color: underlineColor,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900]! : Colors.grey[50]!;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        forceMaterialTransparency: true,
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      // Left/right insets (a notch or a gesture bar sits on the sides when the
      // phone is sideways) always apply; the bottom one only in landscape, so
      // portrait keeps its current edge-to-edge scrolling.
      body: SafeArea(
        top: false,
        bottom: context.isLandscape,
        child: Consumer<SettingsProvider>(
          builder: (context, settingsProvider, child) {
            // One column of cards in every orientation. In landscape the list
            // is padded in so the cards stay at most 600dp wide and centred,
            // while the scroll view (and its scrollbar) still spans the full
            // width. Portrait keeps its 16dp margin.
            return LayoutBuilder(
              builder: (context, constraints) {
                final horizontal = context.isLandscape
                    ? math.max(16.0, (constraints.maxWidth - 600) / 2)
                    : 16.0;
                return ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontal,
                    vertical: 16,
                  ),
                  children: [
                    SectionCard(
                      title: 'Appearance',
                      icon: HugeIcons.strokeRoundedPaintBoard,
                      children: [
                        Consumer<ThemeProvider>(
                          builder: (_, themeProvider, child) {
                            return SwitchTile(
                              title: 'Dark Mode',
                              subtitle: themeProvider.isDarkMode
                                  ? 'Dark theme is active'
                                  : 'Light theme is active',
                              icon: themeProvider.isDarkMode
                                  ? HugeIcons.strokeRoundedMoon02
                                  : HugeIcons.strokeRoundedSun03,
                              value: themeProvider.isDarkMode,
                              onChanged: (value) async {
                                await themeProvider.setDarkMode(value);
                                if (mounted) {
                                  CustomSnackbar.showSuccess(
                                    this.context,
                                    'Theme changed to ${value ? 'dark' : 'light'} mode',
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SectionCard(
                      title: 'Security',
                      icon: HugeIcons.strokeRoundedSecurity,
                      children: [
                        SwitchTile(
                          title: 'App Lock',
                          subtitle: _authStatusDescription,
                          icon: _isBiometricAvailable
                              ? HugeIcons.strokeRoundedFingerprintScan
                              : HugeIcons.strokeRoundedLockPassword,
                          value: _isBiometricEnabled,
                          onChanged: (value) {
                            if (_isBiometricAvailable) {
                              _toggleBiometric(value);
                            } else {
                              CustomSnackbar.showError(
                                context,
                                'Biometric authentication not available on this device',
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    SectionCard(
                      title: 'Language & Region',
                      icon: HugeIcons.strokeRoundedSettings02,
                      headerTrailing: IconButton(
                        tooltip: 'Refresh',
                        onPressed: () async {
                          await Future.wait([
                            settingsProvider.fetchAvailableCurrencies(
                              markManual: true,
                            ),
                            settingsProvider.fetchAvailableTimezones(
                              markManual: true,
                            ),
                            settingsProvider.fetchUserTimezone(),
                          ]);
                          if (mounted) {
                            CustomSnackbar.showInfo(
                              this.context,
                              'Language & Region refreshed',
                            );
                          }
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                      ),
                      children: [
                        OdooDropdownTile(
                          title: 'Language',
                          subtitle: 'Select your preferred language',
                          icon: HugeIcons.strokeRoundedTranslate,
                          selectedValue: 'English',
                          options: const [],
                          isLoading: settingsProvider.isLoadingLanguages,
                          onChanged: (_) {},
                          displayKey: 'name',
                          valueKey: 'code',
                          lastUpdated: settingsProvider.languagesUpdatedAt,
                        ),
                        OdooDropdownTile(
                          title: 'Currency',
                          subtitle: 'Default currency for transactions',
                          icon: HugeIcons.strokeRoundedDollar01,
                          selectedValue: settingsProvider.selectedCurrency,
                          options: settingsProvider.availableCurrencies,
                          isLoading: settingsProvider.isLoadingCurrencies,
                          onChanged: (value) async {
                            try {
                              await settingsProvider.updateCurrency(value!);
                              if (mounted) {
                                CustomSnackbar.showSuccess(
                                  this.context,
                                  'Currency updated to ${settingsProvider.getCurrencyDisplayName(value)}',
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                CustomSnackbar.showError(
                                  this.context,
                                  'Failed to update currency: $e',
                                );
                              }
                            }
                          },
                          displayKey: 'full_name',
                          valueKey: 'name',
                          lastUpdated: settingsProvider.currenciesUpdatedAt,
                        ),
                        OdooDropdownTile(
                          title: 'Timezone',
                          subtitle: 'Your local timezone',
                          icon: HugeIcons.strokeRoundedClock01,
                          selectedValue: settingsProvider.selectedTimezone,
                          options: settingsProvider.availableTimezones,
                          isLoading: settingsProvider.isLoadingTimezones,
                          onChanged: (value) async {
                            try {
                              await settingsProvider.updateTimezone(value!);
                              if (mounted) {
                                CustomSnackbar.showSuccess(
                                  this.context,
                                  'Timezone updated to ${settingsProvider.getTimezoneDisplayName(value)}',
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                CustomSnackbar.showError(
                                  this.context,
                                  'Failed to update timezone: $e',
                                );
                              }
                            }
                          },
                          displayKey: 'name',
                          valueKey: 'code',
                          lastUpdated: settingsProvider.timezonesUpdatedAt,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SectionCard(
                      title: 'Help & Support',
                      icon: HugeIcons.strokeRoundedCustomerSupport,
                      children: [
                        ActionTile(
                          title: 'Odoo Help Center',
                          subtitle: 'Documentation, guides and resources',
                          icon: HugeIcons.strokeRoundedHelpCircle,
                          onTap: () => _launchUrlSmart(
                            'https://www.odoo.com/documentation',
                            title: 'Odoo Help Center',
                          ),
                        ),
                        ActionTile(
                          title: 'Odoo Support',
                          subtitle: 'Create a ticket with Odoo Support',
                          icon: HugeIcons.strokeRoundedCustomerSupport,
                          onTap: () => _launchUrlSmart(
                            'https://www.odoo.com/help',
                            title: 'Odoo Support',
                          ),
                        ),
                        ActionTile(
                          title: 'Odoo Community Forum',
                          subtitle: 'Ask the community for help',
                          icon: HugeIcons.strokeRoundedUserGroup,
                          onTap: () => _launchUrlSmart(
                            'https://www.odoo.com/forum/help-1',
                            title: 'Odoo Forum',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SectionCard(
                      title: 'About',
                      icon: HugeIcons.strokeRoundedBuilding06,
                      children: [_buildAboutContent(context)],
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
