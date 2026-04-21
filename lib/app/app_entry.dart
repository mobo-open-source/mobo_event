import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/widgets/loaders/loading_indicator.dart';
import '../shared/widgets/errors/module_not_installed_error.dart';

import '../features/login/pages/server_setup_screen.dart';
import '../features/login/pages/app_lock_screen.dart';

import '../core/services/session_service.dart';
import '../core/services/odoo_session_manager.dart';
import '../core/services/biometric_context_service.dart';
import '../core/services/connectivity_service.dart';
import '../core/routing/page_transition.dart';

import 'home_scaffold.dart';

class AppEntry extends StatefulWidget {
  final bool skipBiometric;

  const AppEntry({super.key, this.skipBiometric = false});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  late Future<Map<String, dynamic>> _initFuture;
  bool _moduleDialogShown = false;

  @override
  void initState() {
    super.initState();
    ConnectivityService.instance.startMonitoring();
    _initFuture = _checkAuthStatus();
  }

  Future<Map<String, dynamic>> _checkAuthStatus() async {
    await SessionService.instance.initialize();
    final prefs = await SharedPreferences.getInstance();

    final session = SessionService.instance.currentSession;
    final isLoggedIn = session != null;
    final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;

    bool sessionValid = false;
    bool eventInstalled = false;
    bool forceServerSetup = false;

    if (isLoggedIn) {
      sessionValid = await OdooSessionManager.isSessionValid();

      if (sessionValid) {
        try {
          final client = await OdooSessionManager.getClientEnsured();

          /// Extra session sanity check
          await client.callRPC('/web/session/get_session_info', 'call', {});

          ///Event module check
          final count = await client.callKw({
            'model': 'ir.module.module',
            'method': 'search_count',
            'args': [
              [
                ['name', '=', 'event'],
                ['state', '=', 'installed'],
              ],
            ],
            'kwargs': {},
          });

          eventInstalled = (count as num) > 0;

          if (eventInstalled) {
            final sessionService = SessionService.instance;
            final currentSession = await OdooSessionManager.getCurrentSession();

            if (currentSession != null) {
              await sessionService.storeAccount(
                currentSession,
                currentSession.password,
                markAsCurrent: true,
              );
            }
          }
        } catch (e) {
          forceServerSetup = true;
        }
      }
    }

    return {
      'isLoggedIn': isLoggedIn && sessionValid,
      'biometricEnabled': biometricEnabled,
      'eventInstalled': eventInstalled,
      'forceServerSetup': forceServerSetup,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: LoadingIndicator()));
        }

        if (snapshot.hasError || snapshot.data == null) {
          return const ServerSetupScreen();
        }

        final data = snapshot.data!;
        final isLoggedIn = data['isLoggedIn'] as bool;
        final biometricEnabled = data['biometricEnabled'] as bool;
        final eventInstalled = data['eventInstalled'] as bool;
        final forceServerSetup = data['forceServerSetup'] as bool;

        if (forceServerSetup) {
          return const ServerSetupScreen();
        }

        final biometricContext = BiometricContextService();
        final shouldSkipBiometric =
            widget.skipBiometric || biometricContext.shouldSkipBiometric;

        ///  Biometric gate
        if (isLoggedIn &&
            biometricEnabled &&
            !shouldSkipBiometric &&
            eventInstalled) {
          return AppLockScreen(
            onAuthenticationSuccess: () {
              Navigator.pushReplacement(
                context,
                dynamicRoute(context, const AppEntry(skipBiometric: true)),
              );
            },
          );
        }

        /// Event module missing
        if (isLoggedIn && !eventInstalled) {
          if (!_moduleDialogShown) {
            _moduleDialogShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const ModuleMissingDialog(),
              );
            });
          }
          return const ServerSetupScreen();
        }

        ///  Logged in → App
        if (isLoggedIn) {
          return const HomeScaffold();
        }

        ///  Not logged in
        return const ServerSetupScreen();
      },
    );
  }
}
