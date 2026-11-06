import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/app_entry.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/routing/page_transition.dart';
import '../../../core/services/biometric_context_service.dart';
import '../../../core/services/event_access_gate.dart';
import '../../../core/services/event_module_gate.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../../core/services/session_service.dart';
import '../../../core/utils/database_expiry.dart';
import '../../../shared/widgets/dialogs/access_denied_dialog.dart';
import '../../../shared/widgets/dialogs/module_missing_dialog.dart';
import '../../../shared/widgets/loaders/loading_widget.dart';
import '../../home/providers/home_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/login_provider.dart';
import '../utils/auth_failure.dart';
import 'login_layout.dart';
import 'otp_page.dart';
import 'reset_password_screen.dart';

/// How an Add Account attempt ended. Returned rather than acted on inside
/// `_addNewAccount`, so the outcome is only presented once the button has
/// stopped loading.
enum _AddAccountResult {
  /// Signed in, registered and made active; navigation already happened.
  added,

  /// Refused, with the reason in [LoginProvider.errorMessage].
  failed,

  /// The server has no Event module. The previous account is back in place.
  moduleMissing,

  /// The credentials belong to a portal user. Nothing was kept.
  portalUser,

  /// The database's subscription has expired. Nothing was kept, and the
  /// previous account was never replaced. The user is sent back to the server
  /// screen, where the database is chosen.
  databaseExpired,

  /// An internal user with no Event role. The previous account is back in
  /// place and nothing was kept.
  noEventAccess,

  /// The user backed out of the two-factor screen.
  dismissed,
}

class CredentialsScreen extends StatefulWidget {
  final String url;
  final String database;
  final bool isAddingAccount;
  final String? prefilledUsername;

  /// True when the server screen is the route directly beneath this one, so an
  /// expired database can hand its message back to it by popping with it.
  final bool fromServerSetup;

  const CredentialsScreen({
    super.key,
    required this.url,
    required this.database,
    this.isAddingAccount = false,
    this.prefilledUsername,
    this.fromServerSetup = false,
  });

  @override
  State<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends State<CredentialsScreen> {
  late LoginProvider _provider;

  /// Control when to show validation messages
  bool _shouldValidate = false;

  /// Track field-level errors
  bool emailHasError = false;
  bool passwordHasError = false;

  /// General/inline error shown under fields
  String? inlineError;

  /// Focus management
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _provider = LoginProvider();

    // Filled in synchronously, not after the first frame: `LoginProvider`
    // starts restoring the last-used server the moment it is constructed and
    // only stands down if the URL is already set when it checks. Left for a
    // post-frame callback, that restore could win the race — listing the
    // *previous* server's databases, overwriting the database passed in here,
    // and surfacing that server's listing errors on this screen.
    _provider.urlController.text = widget.url;
    _provider.setDatabase(widget.database);
    if (widget.prefilledUsername != null &&
        widget.prefilledUsername!.isNotEmpty) {
      _provider.emailController.text = widget.prefilledUsername!;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_provider.emailController.text.isEmpty) {
        FocusScope.of(context).requestFocus(_emailFocus);
      } else {
        FocusScope.of(context).requestFocus(_passwordFocus);
      }
    });
  }

  @override
  void dispose() {
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _provider.dispose();
    super.dispose();
  }

  /// Clears the inline error together with the provider message it mirrors
  /// (see the sync at the top of [build]) — clearing only one would have the
  /// other put it straight back.
  void _clearError() {
    inlineError = null;
    _provider.errorMessage = null;
  }

  /// Unified submit handler used by both the Sign In button and Enter key on password field
  Future<void> _handleSubmit(LoginProvider provider) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _shouldValidate = true;
    });
    final formValid = provider.formKey.currentState?.validate() ?? false;
    setState(() {
      emailHasError = provider.emailController.text.isEmpty;
      passwordHasError = provider.passwordController.text.isEmpty;
      _clearError();
    });

    if (!formValid) {
      await HapticFeedback.lightImpact();
      return;
    }

    if (widget.isAddingAccount) {
      final result = await _addNewAccount(provider);
      if (!mounted) return;
      await _presentAddAccountResult(result, provider);
      return;
    }

    final biometricContext = BiometricContextService();
    biometricContext.startAccountOperation('login');

    final ok = await provider.login(context);

    // Balanced here for every outcome except a 2FA challenge, where
    // TotpPage takes over the operation itself (see its own start/end) —
    // ending it here too would let the app-lock gate re-arm while that
    // screen is still mid-flow.
    if (ok != LoginResult.twoFactorRequired) {
      biometricContext.endAccountOperation('login');
    }

    if (!mounted) return;

    switch (ok) {
      case LoginResult.success:
        setState(_clearError);

        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;

        TextInput.finishAutofillContext(shouldSave: true);
        _resetAccountScopedState();

        Navigator.of(context).pushAndRemoveUntil(
          dynamicRoute(context, const AppEntry()),
          (route) => false,
        );

      case LoginResult.twoFactorRequired:
        final rejection = await Navigator.push<TotpRejection>(
          context,
          MaterialPageRoute(
            builder: (_) => TotpPage(
              serverUrl: provider.getFullUrl(),
              database: provider.database!,
              username: provider.emailController.text.trim(),
              password: provider.passwordController.text.trim(),
              addaccount: false,
            ),
          ),
        );
        if (!mounted) return;
        await _presentTotpRejection(rejection);

      case LoginResult.invalidCredentials:
        await HapticFeedback.heavyImpact();
        if (!mounted) return;
        setState(
          () => inlineError =
              provider.errorMessage ?? 'Invalid username or password',
        );

      case LoginResult.networkError:
        await HapticFeedback.heavyImpact();
        if (!mounted) return;
        setState(() => inlineError = provider.errorMessage ?? 'Network error');

      case LoginResult.portalUser:
        await _rejectAccount(
          AccessDenial.portalUser,
          provider.errorMessage ?? PortalUserException.portalUserMessage,
        );

      case LoginResult.databaseExpired:
        await _returnToServerSetup(
          provider.errorMessage ?? DatabaseExpiredException.message,
        );

      case LoginResult.noEventAccess:
        await _rejectAccount(AccessDenial.noEventAccess);

      case LoginResult.moduleMissing:
        await _showModuleMissing();
    }
  }

  Future<void> _presentAddAccountResult(
    _AddAccountResult result,
    LoginProvider provider,
  ) async {
    switch (result) {
      case _AddAccountResult.added || _AddAccountResult.dismissed:
        break;

      case _AddAccountResult.failed:
        await HapticFeedback.heavyImpact();
        if (!mounted) return;
        setState(() {
          inlineError = provider.errorMessage ?? 'Failed to add account';
        });

      case _AddAccountResult.moduleMissing:
        await _showModuleMissing();

      case _AddAccountResult.portalUser:
        await _rejectAccount(
          AccessDenial.portalUser,
          provider.errorMessage ?? PortalUserException.portalUserMessage,
        );

      case _AddAccountResult.databaseExpired:
        await _returnToServerSetup(
          provider.errorMessage ?? DatabaseExpiredException.message,
        );

      case _AddAccountResult.noEventAccess:
        await _rejectAccount(AccessDenial.noEventAccess);
    }
  }

  Future<void> _presentTotpRejection(TotpRejection? rejection) async {
    switch (rejection) {
      case TotpModuleMissing():
        await _showModuleMissing();
      case TotpPortalUser(:final message):
        await _rejectAccount(AccessDenial.portalUser, message);
      case TotpDatabaseExpired():
        await _returnToServerSetup(DatabaseExpiredException.message);
      case TotpNoEventAccess():
        await _rejectAccount(AccessDenial.noEventAccess);
      case null:
        break;
    }
  }

  /// Sends the user back to the server screen with [message] shown there: an
  /// expired database can only be got around by choosing another one, and that
  /// is where the database is chosen. Only this screen is popped, so
  /// everything beneath it stays as the user left it.
  ///
  /// Sign-in opened straight from the account switcher has no server screen
  /// beneath it, so there the message stays on this screen instead.
  Future<void> _returnToServerSetup(String message) async {
    await HapticFeedback.heavyImpact();
    if (!mounted) return;

    final navigator = Navigator.of(context);
    if (widget.fromServerSetup && navigator.canPop()) {
      navigator.pop<String>(message);
      return;
    }

    setState(() {
      inlineError = message;
      _provider.errorMessage = message;
    });
  }

  /// Refuses an account that signed in correctly but cannot use this app — a
  /// portal user, or an internal user with no Event role — without leaving the
  /// credentials screen.
  ///
  /// Nothing was kept (the portal check rejects before saving, and the
  /// access check restores the previous session), so there is no navigation
  /// and no cleanup to do here — the user stays on this screen with their
  /// email intact and can retype credentials for an account that has access.
  ///
  /// The password is cleared deliberately: the next attempt is a *different*
  /// account, not a retry of this one, so leaving the old password in the
  /// field would only invite re-submitting the same rejected pair.
  Future<void> _rejectAccount(AccessDenial denial, [String? message]) async {
    final text = message ?? denial.message;
    await HapticFeedback.heavyImpact();
    if (!mounted) return;

    setState(() {
      inlineError = text;
      _provider.errorMessage = text;
      passwordHasError = true;
      _provider.passwordController.clear();
    });

    await showAccessDeniedDialog(context, denial: denial, message: text);
  }

  /// Nothing was kept, and the only way past a missing module is a different
  /// server or database — so "Back to Login" steps back to the screen where
  /// those are chosen. Only this screen is popped: everything beneath it
  /// (the server picker, and for Add Account the Profile screen and the app
  /// behind it) stays exactly as the user left it.
  Future<void> _showModuleMissing() async {
    setState(_clearError);
    await HapticFeedback.heavyImpact();
    if (!mounted) return;

    await showModuleMissingDialog(context);
    if (!mounted) return;

    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  /// Drops data the app-wide providers still hold for whichever account was
  /// active before, so the next screens don't show it while they reload.
  void _resetAccountScopedState() {
    context.read<HomeProvider>().clearProvider();
    context.read<ProfileProvider>().resetState();
  }

  Future<_AddAccountResult> _addNewAccount(LoginProvider provider) async {
    // Cleared up front the same way [LoginProvider.login] clears it, so a
    // message left over from the previous attempt cannot be shown while this
    // one is still running.
    provider.errorMessage = null;
    provider.setBusy(true);

    // Mark as account operation to prevent biometric prompt
    final biometricContext = BiometricContextService();
    biometricContext.startAccountOperation('add_account');

    final sessionService = SessionService.instance;
    final previous = sessionService.currentSession;
    final serverUrl = _ensureScheme(
      widget.url.isNotEmpty ? widget.url : (previous?.serverUrl ?? ''),
    );
    final database = widget.database.isNotEmpty
        ? widget.database
        : (previous?.database ?? '');
    final username = provider.emailController.text.trim();
    final password = provider.passwordController.text;

    // Restores whichever account was active before this attempt started —
    // called on every failure path below that ran past `authenticate()`,
    // so a rejected add-account attempt never leaves the in-memory session
    // pointed at an account that was never actually committed.
    Future<void> rollback() async {
      if (previous != null) {
        await OdooSessionManager.updateSession(previous);
      } else {
        await OdooSessionManager.logout();
      }
    }

    // Set once the two-factor screen has taken over the biometric operation,
    // so the `finally` below doesn't end it out from under that screen.
    var handedToTwoFactor = false;

    try {
      if (serverUrl.isEmpty || database.isEmpty) {
        provider.errorMessage =
            'Server URL or Database is missing. Please go back and try again.';
        return _AddAccountResult.failed;
      }

      final newSession = await OdooSessionManager.authenticate(
        serverUrl: serverUrl,
        database: database,
        username: username,
        password: password,
      );

      if (newSession == null) {
        provider.errorMessage =
            'Authentication failed. Please check your credentials.';
        return _AddAccountResult.failed;
      }

      // A server without the Event module is always reported as that,
      // rather than the user only discovering it later on the home screen
      // with the previous account already replaced.
      final client = await OdooSessionManager.getClientEnsured();
      if (!await isEventModuleInstalled(client)) {
        await rollback();
        return _AddAccountResult.moduleMissing;
      }

      // Likewise an account with no Event role: it must never reach the
      // switcher, or replace the account the user is already signed in as.
      if (!await hasEventAccess(client)) {
        await rollback();
        return _AddAccountResult.noEventAccess;
      }

      // `authenticate()` has already resolved the user's companies.
      final fixedSession = newSession.copyWith(
        selectedCompanyId: newSession.companyId,
      );
      await OdooSessionManager.updateSession(fixedSession);
      sessionService.updateSession(fixedSession);

      await _rememberServer(serverUrl, database);

      // Register the account so it appears in the switcher, then make it
      // active — done only now that the module gate above has passed.
      await sessionService.storeAccount(fixedSession, password);
      await sessionService.switchToAccount(fixedSession);

      if (mounted) {
        TextInput.finishAutofillContext(shouldSave: true);
        _resetAccountScopedState();
        Navigator.of(context).pushAndRemoveUntil(
          dynamicRoute(context, const AppEntry()),
          (route) => false,
        );
      }
      return _AddAccountResult.added;
    } catch (e) {
      // By type, ahead of the string matching below. `authenticate()` throws
      // it before it points the cached session at the new account, so
      // there is nothing to roll back.
      if (e is DatabaseExpiredException) {
        provider.errorMessage = DatabaseExpiredException.message;
        return _AddAccountResult.databaseExpired;
      }

      if (isTwoFactorError(e)) {
        // `authenticate()` throws this before it ever touches the cached
        // session, so there is nothing to roll back. The button stops
        // loading before the code screen opens; that screen owns the
        // biometric operation from here and ends it itself.
        handedToTwoFactor = true;
        provider.setBusy(false);
        if (!mounted) return _AddAccountResult.dismissed;

        final rejection = await Navigator.push<TotpRejection>(
          context,
          MaterialPageRoute(
            builder: (_) => TotpPage(
              serverUrl: serverUrl,
              database: database,
              username: username,
              password: password,
              addaccount: true,
            ),
          ),
        );
        switch (rejection) {
          case TotpModuleMissing():
            return _AddAccountResult.moduleMissing;
          case TotpPortalUser(:final message):
            provider.errorMessage = message;
            return _AddAccountResult.portalUser;
          case TotpDatabaseExpired():
            provider.errorMessage = DatabaseExpiredException.message;
            return _AddAccountResult.databaseExpired;
          case TotpNoEventAccess():
            return _AddAccountResult.noEventAccess;
          case null:
            return _AddAccountResult.dismissed;
        }
      }

      await rollback();

      if (e is PortalUserException) {
        provider.errorMessage = e.message;
        return _AddAccountResult.portalUser;
      }

      // `authenticate()` lets the raw Odoo exception through — its
      // `toString()` is the whole server error map, traceback included — so
      // it is turned into one readable sentence here.
      provider.errorMessage = authFailureMessage(
        e,
        fallback:
            'Failed to add account. Please check your credentials and '
            'server settings.',
      );
      return _AddAccountResult.failed;
    } finally {
      if (!handedToTwoFactor) {
        biometricContext.endAccountOperation('add_account');
      }
      provider.setBusy(false);
    }
  }

  /// Persists server URL history and the server → database mapping, so the
  /// server picker can offer this server again next time.
  Future<void> _rememberServer(String serverUrl, String database) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      List<String> urls = prefs.getStringList('previous_server_urls') ?? [];
      if (!urls.contains(serverUrl)) {
        urls.insert(0, serverUrl);
        if (urls.length > 10) {
          urls = urls.take(10).toList();
        }
        await prefs.setStringList('previous_server_urls', urls);
      }

      await prefs.setString('server_db_$serverUrl', database);
    } catch (_) {
      // Non-fatal: ignore persistence errors
    }
  }

  /// Ensures the URL has a scheme (http/https). Defaults to https if missing.
  String _ensureScheme(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    final hasScheme =
        trimmed.startsWith('http://') || trimmed.startsWith('https://');
    return hasScheme ? trimmed : 'https://$trimmed';
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<LoginProvider>(
        builder: (context, provider, child) {
          // Sync inlineError with provider.errorMessage
          if (provider.errorMessage != inlineError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                inlineError = provider.errorMessage;
              });
            });
          }

          // Leaving mid-attempt would let an add-account finish in the
          // background — switching the active account with no navigation to
          // show for it — so back is held until the attempt settles.
          return PopScope(
            canPop: !provider.isLoading,
            child: LoginLayout(
              title: widget.isAddingAccount ? 'Add Account' : 'Sign In',
              subtitle: widget.isAddingAccount
                  ? 'Enter credentials for the new account'
                  : 'Enter your credentials to continue',
              backButton: LoginBackButton(
                onPressed: provider.isLoading
                    ? null
                    : () => Navigator.of(context).pop(),
              ),
              child: Form(
                key: provider.formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LoginTextField(
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        controller: provider.emailController,
                        hint: 'Email',
                        prefixIcon: HugeIcon(
                          icon: HugeIcons.strokeRoundedMail01,
                          size: 20,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        enabled: !provider.disableFields,
                        focusNode: _emailFocus,
                        textInputAction: TextInputAction.next,
                        hasError: emailHasError,
                        autovalidateMode: _shouldValidate
                            ? AutovalidateMode.onUserInteraction
                            : AutovalidateMode.disabled,
                        validator: (value) {
                          if (provider.isLoadingDatabases || !_shouldValidate) {
                            return null;
                          }
                          if (value == null || value.isEmpty) {
                            return 'Email is required';
                          }
                          return null;
                        },
                        onChanged: (val) {
                          setState(() {
                            emailHasError = val.isEmpty;
                            _clearError();
                          });
                        },
                        onFieldSubmitted: (_) {
                          FocusScope.of(context).requestFocus(_passwordFocus);
                        },
                      ),
                      const SizedBox(height: 16),

                      LoginTextField(
                        autofillHints: const [AutofillHints.password],
                        controller: provider.passwordController,
                        hint: 'Password',
                        prefixIcon: HugeIcon(
                          icon: HugeIcons.strokeRoundedLockPassword,
                          size: 20,
                        ),
                        obscureText: provider.obscurePassword,
                        enabled: !provider.disableFields,
                        focusNode: _passwordFocus,
                        textInputAction: TextInputAction.done,
                        hasError: passwordHasError,
                        autovalidateMode: _shouldValidate
                            ? AutovalidateMode.onUserInteraction
                            : AutovalidateMode.disabled,
                        validator: (value) {
                          if (provider.isLoadingDatabases || !_shouldValidate) {
                            return null;
                          }
                          if (value == null || value.isEmpty) {
                            return 'Password is required';
                          }
                          return null;
                        },
                        suffixIcon: IconButton(
                          icon: Icon(
                            provider.obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.black54,
                            size: 20,
                          ),
                          onPressed: provider.togglePasswordVisibility,
                        ),
                        onChanged: (val) {
                          setState(() {
                            passwordHasError = val.isEmpty;
                            _clearError();
                          });
                        },
                        onFieldSubmitted: (_) async {
                          if (!(provider.isLoading ||
                              provider.isLoadingDatabases)) {
                            await _handleSubmit(provider);
                          }
                        },
                      ),
                      const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: provider.isLoading
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    dynamicRoute(
                                      context,
                                      ResetPasswordScreen(
                                        url: widget.url,
                                        database: widget.database,
                                      ),
                                    ),
                                  );
                                },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Forgot Password?',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      LoginErrorDisplay(error: inlineError),

                      LoginButton(
                        text: widget.isAddingAccount
                            ? 'Add Account'
                            : 'Sign In',
                        isLoading: provider.isLoading,
                        loadingWidget: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.isAddingAccount
                                  ? 'Adding Account'
                                  : 'Signing In',
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const LoadingWidget(
                              color: Colors.white,
                              size: 20,
                              variant: LoadingVariant.staggeredDots,
                            ),
                          ],
                        ),
                        onPressed:
                            provider.isLoading || provider.isLoadingDatabases
                            ? null
                            : () async {
                                await _handleSubmit(provider);
                              },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
