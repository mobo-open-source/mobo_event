import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_event/features/home/providers/home_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import '../core/services/database_expiry_guard.dart';
import '../core/services/event_access_rights.dart';
import '../core/services/odoo_session_manager.dart';
import '../core/services/connectivity_service.dart';
import '../features/event/provider/event_detailed_provider.dart';
import '../features/home/pages/home_screen.dart';
import '../features/review/services/review_service.dart';
import '../features/profile/pages/profile_screen.dart';
import '../features/profile/providers/profile_provider.dart';
import '../core/routing/page_transition.dart';
import '../features/company/providers/company_provider.dart';
import '../features/company/widgets/company_selector_widget.dart';
import '../shared/widgets/snackbars/custom_snackbar.dart';
import '../shared/widgets/odoo_avatar.dart';

class HomeScaffold extends StatefulWidget {
  const HomeScaffold({super.key});

  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold>
    with WidgetsBindingObserver {
  bool _isStockUser = false;
  bool _isLoadingSession = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    ConnectivityService.instance.startMonitoring();
    OdooSessionManager.getCurrentSession().then((session) {
      ConnectivityService.instance.setCurrentServerUrl(session?.serverUrl);
      if (mounted) {
        setState(() {
          _isStockUser = session?.isStockUser ?? false;
          _isLoadingSession = false;
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ReviewService().checkAndShowRating(context);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CompanyProvider>().initialize();
        context.read<ProfileProvider>().fetchUserProfile();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      unawaited(DatabaseExpiryGuard.onAppResumed());
      _validateSession();
      if (mounted) {
        context.read<ProfileProvider>().fetchUserProfile(forceRefresh: true);
      }
    }
  }

  Future<void> _validateSession() async {
    try {
      final isValid = await OdooSessionManager.isSessionValid();
      if (!isValid && mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/server_setup', (route) => false);
      } else if (mounted) {
        // Refresh permission check on resume — an administrator may have
        // changed this account's Events role while the app was away.
        unawaited(context.read<AccessRights>().load(force: true));
        final session = await OdooSessionManager.getCurrentSession();
        if (session != null && session.isStockUser != _isStockUser) {
          setState(() {
            _isStockUser = session.isStockUser;
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // CompanyProvider is now provided globally in main.dart
    return Scaffold(body: _buildScreenWithAppBar(Container()));
  }

  Widget _buildScreenWithAppBar(Widget screen) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          "Dashboard",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: _buildProfileActions(context),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),

      body: HomeScreen(),
    );
  }

  List<Widget> _buildProfileActions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return [
      CompanySelectorWidget(
        onCompanyChanged: () async {
          if (!mounted) return;

          final provider = context.read<CompanyProvider>();
          final companyName =
              provider.selectedCompany?['name']?.toString() ?? 'company';

          final homeProvider = Provider.of<HomeProvider>(
            context,
            listen: false,
          );
          final profileProvider = Provider.of<ProfileProvider>(
            context,
            listen: false,
          );
          final eventProvider = Provider.of<EventDetailedProvider>(
            context,
            listen: false,
          );

          try {
            homeProvider.setLoading(true);

            await Future.wait([
              profileProvider.fetchUserProfile(forceRefresh: true),
              eventProvider.loadFields(),
              eventProvider.loadFieldOfTicket(),
              homeProvider.gettingStages(),
              homeProvider.loadEvents(),
            ]);

            if (!mounted) return;

            CustomSnackbar.showSuccess(context, 'Switched to $companyName');
          } catch (_) {
            if (!mounted) return;

            CustomSnackbar.showError(context, 'Failed to switch company');
          } finally {
            homeProvider.setLoading(false);
          }
        },
      ),
      Container(
        margin: const EdgeInsets.only(right: 8),
        child: Consumer<ProfileProvider>(
          builder: (context, profileProvider, child) {
            final avatarBase64 = profileProvider.userAvatarBase64;
            final isLoading = profileProvider.isLoading && avatarBase64 == null;

            return IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isLoading
                    ? SizedBox(
                        key: const ValueKey('avatar_loading'),
                        width: 32,
                        height: 32,
                        child: Shimmer.fromColors(
                          baseColor: isDark
                              ? Colors.grey[700]!
                              : Colors.grey[300]!,
                          highlightColor: isDark
                              ? Colors.grey[600]!
                              : Colors.grey[200]!,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800] : Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      )
                    : (avatarBase64 != null
                          // Same renderer as the profile header, so the photo
                          // looks the same in both places — including the SVG
                          // avatar Odoo generates for users with no photo.
                          ? OdooAvatar(
                              key: const ValueKey('avatar_image'),
                              imageBase64: avatarBase64,
                              size: 30,
                              iconSize: 18,
                              placeholderColor: isDark
                                  ? Colors.grey[800]
                                  : Colors.grey[300],
                              iconColor: isDark
                                  ? Colors.white70
                                  : Colors.black54,
                              fallbackIcon: HugeIcons.strokeRoundedUserCircle,
                              borderRadius: BorderRadius.circular(15),
                            )
                          : CircleAvatar(
                              key: const ValueKey('avatar_placeholder'),
                              radius: 16,
                              backgroundColor: isDark
                                  ? Colors.grey[800]
                                  : Colors.grey[300],
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedUserCircle,
                                color: isDark ? Colors.white70 : Colors.black54,
                                size: 18,
                              ),
                            )),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  dynamicRoute(context, const ProfileScreen()),
                ).then((_) {
                  if (mounted) {
                    context.read<ProfileProvider>().fetchUserProfile(
                      forceRefresh: true,
                    );
                  }
                });
              },
            );
          },
        ),
      ),
    ];
  }
}
