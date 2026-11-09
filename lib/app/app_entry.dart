import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/widgets/loaders/loading_indicator.dart';
import '../shared/widgets/dialogs/access_denied_dialog.dart';
import '../shared/widgets/dialogs/module_missing_dialog.dart';

import '../features/login/pages/server_setup_screen.dart';
import '../features/login/pages/app_lock_screen.dart';

import '../core/services/session_service.dart';
import '../core/services/odoo_session_manager.dart';
import '../core/services/biometric_context_service.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/event_access_gate.dart';
import '../core/services/event_module_gate.dart';
import '../core/routing/page_transition.dart';
import '../core/utils/database_expiry.dart';

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
  bool _accessDialogShown = false;

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
    bool eventAccess = true;
    bool forceServerSetup = false;

    if (isLoggedIn) {
      sessionValid = await OdooSessionManager.isSessionValid();

      if (sessionValid) {
        try {
          final client = await OdooSessionManager.getClientEnsured();

          final sessionInfo = await client.callRPC(
            '/web/session/get_session_info',
            'call',
            {},
          );

          // First thing once the session proves valid, ahead of the module
          // and access checks, and read from the answer just received rather
          // than asked for again. Only the current account is signed out; the
          // other saved accounts stay where they are.
          if (DatabaseExpiry.hasExpired(
            sessionInfo is Map
                ? sessionInfo[DatabaseExpiry.sessionInfoKey]
                : null,
          )) {
            await OdooSessionManager.logout();
            return {
              'isLoggedIn': false,
              'biometricEnabled': biometricEnabled,
              'eventInstalled': false,
              'eventAccess': true,
              'forceServerSetup': false,
              'databaseExpired': true,
            };
          }

          eventInstalled = await isEventModuleInstalled(client);

          // A session saved before the sign-in flows checked Event access
          // (or one whose Event role has since been taken away) meets the
          // same refusal a fresh sign-in would.
          if (eventInstalled) eventAccess = await hasEventAccess(client);

          if (eventInstalled && eventAccess) {
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
        } catch (_) {
          forceServerSetup = true;
        }
      }
    }

    return {
      'isLoggedIn': isLoggedIn && sessionValid,
      'biometricEnabled': biometricEnabled,
      'eventInstalled': eventInstalled,
      'eventAccess': eventAccess,
      'forceServerSetup': forceServerSetup,
      'databaseExpired': false,
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
        final eventAccess = data['eventAccess'] as bool;
        final forceServerSetup = data['forceServerSetup'] as bool;
        final databaseExpired = data['databaseExpired'] as bool;

        if (forceServerSetup) {
          return const ServerSetupScreen();
        }

        // The session was ended above. The server screen is where the
        // database is chosen, so it is where the reason is shown.
        if (databaseExpired) {
          return const ServerSetupScreen(
            initialError: DatabaseExpiredException.message,
          );
        }

        final biometricContext = BiometricContextService();
        final shouldSkipBiometric =
            widget.skipBiometric || biometricContext.shouldSkipBiometric;

        if (isLoggedIn &&
            biometricEnabled &&
            !shouldSkipBiometric &&
            eventInstalled &&
            eventAccess) {
          return AppLockScreen(
            onAuthenticationSuccess: () {
              Navigator.pushReplacement(
                context,
                dynamicRoute(context, const AppEntry(skipBiometric: true)),
              );
            },
          );
        }

        if (isLoggedIn && !eventInstalled) {
          if (!_moduleDialogShown) {
            _moduleDialogShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) showModuleMissingDialog(context);
            });
          }
          return const ServerSetupScreen();
        }

        if (isLoggedIn && !eventAccess) {
          if (!_accessDialogShown) {
            _accessDialogShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                showAccessDeniedDialog(
                  context,
                  denial: AccessDenial.noEventAccess,
                  actionLabel: 'Back to Login',
                );
              }
            });
          }
          return const ServerSetupScreen();
        }

        if (isLoggedIn) {
          return const HomeScaffold();
        }

        return const ServerSetupScreen();
      },
    );
  }
}
