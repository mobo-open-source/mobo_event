import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../../app/app_entry.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/routing/page_transition.dart';
import '../../../core/services/biometric_context_service.dart';
import '../../../core/services/event_access_gate.dart';
import '../../../core/services/event_module_gate.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../../core/services/session_service.dart';
import '../../../core/utils/database_expiry.dart';
import '../../../core/utils/screen_layout.dart';
import '../../../shared/widgets/loaders/loading_widget.dart';
import '../../home/providers/home_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/login_provider.dart';
import '../services/totp_http_login_service.dart';
import 'login_layout.dart';
import '../widgets/totp_webview_fallback.dart';

/// Why [TotpPage] closed without signing in, handed back as its route result.
///
/// The page only ever pops itself; the screen that opened it decides what the
/// user sees next. That keeps every caller in charge of its own part of the
/// navigation stack instead of this page guessing how deep that stack is —
/// it is reached from the sign-in screen, from Add Account, and directly from
/// the Profile screen when a switch hits a two-factor challenge.
sealed class TotpRejection {
  const TotpRejection();
}

/// The server has no Event module installed. The previous session has
/// already been restored by the time the caller sees this.
final class TotpModuleMissing extends TotpRejection {
  const TotpModuleMissing();
}

/// The credentials belong to a portal (share) user. Nothing was kept.
final class TotpPortalUser extends TotpRejection {
  const TotpPortalUser(this.message);

  final String message;
}

/// The database's subscription has expired. Nothing was kept — the check runs
/// before the session is saved or cached.
final class TotpDatabaseExpired extends TotpRejection {
  const TotpDatabaseExpired();
}

/// An internal user who holds no Event role, so the server refuses them
/// `event.event`. The previous session has already been restored by the time
/// the caller sees this.
final class TotpNoEventAccess extends TotpRejection {
  const TotpNoEventAccess();
}

/// TOTP (two-factor authentication) page: collects the six-digit code and
/// completes the Odoo login with it.
///
/// The login is driven by [OdooTotpHttpClient] as three ordinary form
/// requests. The first two — the ones that need only the password — are sent
/// the moment this page opens, while the user is still reaching for their
/// authenticator app, so by the time a code is typed only one round trip is
/// left.
///
/// [TotpWebViewFallback] takes over for servers whose login pages that client
/// does not recognise. On a standard Odoo server no WebView is ever created.
class TotpPage extends StatefulWidget {
  /// The server base URL, e.g. 'https://myodoo.example.com'.
  final String serverUrl;

  /// The Odoo database name chosen on the login screen.
  final String database;

  /// The username (email) used for the initial authentication attempt.
  final String username;

  /// The password used for the initial authentication attempt.
  final String password;

  /// True when this TOTP verification is part of adding (or switching to) a
  /// second account rather than a fresh sign-in, so a success also makes the
  /// new account the active one in the switcher.
  final bool addaccount;

  const TotpPage({
    super.key,
    required this.serverUrl,
    required this.database,
    required this.username,
    required this.password,
    required this.addaccount,
  });

  @override
  State<TotpPage> createState() => _TotpPageState();
}

class _TotpPageState extends State<TotpPage> {
  final _totpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isButtonEnabled = false;

  /// Drives the login over plain HTTP. Null once the flow has handed off to
  /// [_webViewFallback].
  OdooTotpHttpClient? _httpClient;

  /// Only created for servers the HTTP client could not drive.
  TotpWebViewFallbackController? _webViewFallback;

  /// Completes when a code can be submitted. Awaited by [_submitTotp] so a
  /// user who types faster than the handshake still gets a single, seamless
  /// wait rather than a failed attempt.
  late Future<void> _preparation;

  /// Blocking overlay, fallback only — the HTTP handshake never shows one.
  /// It runs in the background while the user reads their code off their
  /// authenticator app, so there is nothing to make them wait for.
  bool _loading = false;

  /// True while a code is in flight, or while the session it produced is
  /// being verified and saved.
  bool _verifying = false;

  /// Set when the flow cannot continue as it stands (refused password,
  /// unreachable server). The next Authenticate tap starts it over.
  bool _blocked = false;

  /// A session the server issued without ever asking for a code, i.e.
  /// two-factor is no longer enabled for this account. Held rather than only
  /// acted on, so a code submitted in the same moment finishes with this
  /// session instead of being sent to a server that is no longer expecting
  /// one.
  String? _sessionWithoutCode;

  String? _error;

  /// Set once this page has either handed a [TotpRejection] back or moved on
  /// into the app, so no later completion (a fallback WebView report racing a
  /// submitted code) can navigate a second time.
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _preparation = _prepare();
  }

  /// Closes this page and hands [rejection] to the screen that opened it.
  void _closeWith(TotpRejection rejection) {
    if (_finished || !mounted) return;
    _finished = true;
    Navigator.of(context).pop(rejection);
  }

  @override
  void dispose() {
    // Safety net for the back-out case: the flow that pushed this page left
    // its biometric account operation open on purpose so the app lock can't
    // fire mid-OTP, and an operation never closed would disable the lock for
    // the rest of the process. Ending it twice is harmless.
    BiometricContextService().endAccountOperation(
      widget.addaccount ? 'add_account' : 'login',
    );
    _httpClient?.close();
    _totpController.dispose();
    super.dispose();
  }

  /// Sends the password half of the login — everything that does not need
  /// the user's code — so only the code submission is left by the time they
  /// have one. Never throws: every outcome is reported through the UI state.
  Future<void> _prepare() async {
    if (_webViewFallback != null) {
      // This server already turned out not to be one the HTTP client can
      // drive; replay the WebView rather than re-testing that.
      await _startWebViewFallback();
      return;
    }

    _httpClient?.close();
    final client = OdooTotpHttpClient(
      serverUrl: widget.serverUrl,
      database: widget.database,
    );
    _httpClient = client;

    TotpHandshake handshake;
    try {
      handshake = await client.begin(
        login: widget.username,
        password: widget.password,
      );
    } on TotpHandshakeUnsupported {
      // A login flow this client does not drive — hand over to the WebView,
      // which renders whatever the server actually serves.
      await _startWebViewFallback();
      return;
    } on SocketException {
      await _startWebViewFallback();
      return;
    } on HandshakeException {
      // A certificate Dart refuses but the WebView is configured to accept.
      await _startWebViewFallback();
      return;
    } on TimeoutException {
      _fail('The server took too long to respond. Please try again.');
      return;
    } catch (_) {
      await _startWebViewFallback();
      return;
    }

    if (!mounted) return;

    switch (handshake.outcome) {
      case TotpHandshakeOutcome.codeRequired:
        break;

      case TotpHandshakeOutcome.authenticated:
        // Two-factor is no longer switched on for this account, and the
        // password alone signed it in. There is no code to ask for.
        // [_signInWithoutCode] still verifies the session with the server
        // before it is kept.
        await _signInWithoutCode(handshake.sessionId!);

      case TotpHandshakeOutcome.credentialsRejected:
        _fail(
          handshake.message ??
              'Sign-in was refused. Please check your credentials and try '
                  'again.',
        );
    }
  }

  /// Signs in with a session the server issued without asking for a code,
  /// which happens only when two-factor is no longer enabled for this
  /// account. Shown as a normal authentication so the screen does not look
  /// frozen while the session is verified and saved.
  Future<void> _signInWithoutCode(String sessionId) async {
    _sessionWithoutCode = sessionId;
    // A submission already in flight picks this session up itself once it is
    // done waiting on the handshake, so this stays out of its way.
    if (_verifying || !mounted) return;
    setState(() => _verifying = true);
    try {
      await _completeLogin(sessionId);
    } catch (_) {
      _showError('Authentication failed. Please try again.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  /// Mounts the WebView fallback and waits for it to reach the TOTP form.
  Future<void> _startWebViewFallback() async {
    if (!mounted) return;

    final fallback = TotpWebViewFallbackController();
    _httpClient?.close();
    setState(() {
      _httpClient = null;
      _webViewFallback = fallback;
      // The only path that still shows the overlay: driving the real login
      // pages means two full page loads before a code can be sent.
      _loading = true;
    });

    try {
      await fallback.ready;
    } catch (_) {
      _fail(
        'Could not reach the sign-in page on this server. Please check your '
        'connection and try again.',
      );
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _submitTotp() async {
    if (_verifying) return;

    final totp = _totpController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(totp)) {
      setState(() => _error = 'Please enter a valid 6-digit code');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      if (_blocked) {
        // The last attempt to reach the server failed outright. Start the
        // whole flow over rather than leaving this button dead.
        setState(() => _blocked = false);
        _preparation = _prepare();
      }

      // Normally already finished — the handshake ran while the code was
      // being read off the authenticator app.
      await _preparation;
      if (!await _readyToSendCode()) return;

      var submission = await _sendCode(totp);

      if (submission.outcome == TotpSubmitOutcome.handshakeExpired) {
        // The partial session aged out while this screen sat open. Replay
        // the password step and resend the same code, which is still inside
        // its own validity window.
        _preparation = _prepare();
        await _preparation;
        if (!await _readyToSendCode()) return;
        submission = await _sendCode(totp);
      }

      if (!mounted) return;

      switch (submission.outcome) {
        case TotpSubmitOutcome.authenticated:
          await _completeLogin(submission.sessionId!);

        case TotpSubmitOutcome.codeRejected:
          _showError(submission.message!);

        case TotpSubmitOutcome.handshakeExpired:
          _showError(
            'Your sign-in attempt expired. Please enter a fresh code.',
          );
      }
    } on TimeoutException {
      _showError('The server took too long to respond. Please try again.');
    } on SocketException {
      _showError(
        'Could not reach the server. Please check your connection and try '
        'again.',
      );
    } catch (_) {
      _showError('Authentication failed. Please try again.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  /// Whether the code still has anywhere to go once the handshake has
  /// settled. A handshake that came back already signed in finishes the
  /// login here instead — sending a code to a server that is no longer
  /// expecting one would only fail.
  Future<bool> _readyToSendCode() async {
    if (!mounted || _blocked) return false;

    final sessionWithoutCode = _sessionWithoutCode;
    if (sessionWithoutCode != null) {
      await _completeLogin(sessionWithoutCode);
      return false;
    }
    return true;
  }

  /// Submits [code] through whichever transport is driving this login,
  /// switching to the WebView fallback if the HTTP one turns out not to
  /// handle this server's TOTP form after all.
  Future<TotpSubmission> _sendCode(String code) async {
    final client = _httpClient;
    if (client != null) {
      try {
        return await client.submitCode(code);
      } on TotpHandshakeUnsupported {
        await _startWebViewFallback();
        if (!mounted || _blocked) {
          return const TotpSubmission.handshakeExpired();
        }
      }
    }

    final fallback = _webViewFallback;
    if (fallback == null) {
      throw StateError('no transport is driving this login');
    }
    await fallback.ready;
    return fallback.submit(code);
  }

  /// Verifies the session the server issued, keeps it, and lands the user in
  /// the app.
  Future<void> _completeLogin(String sessionId) async {
    if (_finished) return;

    // The only authoritative check: ask Odoo whether this session is
    // actually authenticated, and as the expected user. A cookie or a
    // redirect on its own can't tell a verified session apart from one that
    // skipped the challenge entirely.
    final sessionInfo = await OdooTotpHttpClient.fetchSessionInfo(
      serverUrl: widget.serverUrl,
      sessionId: sessionId,
    );

    final uid = sessionInfo?['uid'];
    final sessionLogin = (sessionInfo?['username'] ?? sessionInfo?['login'])
        ?.toString();
    final isVerified =
        uid is int &&
        uid > 0 &&
        (sessionLogin == null ||
            sessionLogin.toLowerCase() == widget.username.trim().toLowerCase());

    if (!isVerified) {
      if (!mounted) return;
      if (_sessionWithoutCode == sessionId) {
        // Nothing for the user to retype: this session came from a server
        // that never asked for a code, so a fresh one would go nowhere.
        _sessionWithoutCode = null;
        _fail('Sign-in could not be completed. Please try again.');
      } else {
        _showError('Invalid code or login failed. Please try again.');
      }
      return;
    }

    final saved = await _saveSessionData(
      sessionId: sessionId,
      sessionInfo: sessionInfo!,
    );
    if (!mounted || !saved || _finished) return;
    _finished = true;

    // The account that just authenticated is not the one the app's providers
    // are holding, and the biometric operation the calling flow left open is
    // closed out here now that the second factor is done.
    BiometricContextService().endAccountOperation(
      widget.addaccount ? 'add_account' : 'login',
    );
    context.read<HomeProvider>().clearProvider();
    context.read<ProfileProvider>().resetState();

    // pushAndRemoveUntil clears the whole login stack, so the back button
    // can't walk a signed-in user back onto the sign-in form.
    Navigator.of(context).pushAndRemoveUntil(
      dynamicRoute(context, const AppEntry()),
      (route) => false,
    );
  }

  /// Persists the session established by the TOTP login, then gates it behind
  /// the same portal-user, Event-module and Event-access checks every other
  /// login path in this app enforces. Returns true only when the session is kept. On a
  /// rejection this page has already closed itself with a [TotpRejection];
  /// on any other failure an inline [_error] tells the user what happened.
  Future<bool> _saveSessionData({
    required String sessionId,
    required Map<String, dynamic> sessionInfo,
  }) async {
    // Snapshotted before this TOTP session is committed below: if the
    // module check that follows rejects it, this is what gets restored so
    // the active client is never left pointed at a rejected account.
    final previousSession = await OdooSessionManager.getCurrentSession();

    if (!mounted) return false;

    // Establish the in-memory session without persisting preferences so we
    // can run the module check before committing this account to persistent
    // storage or SessionService. If the check fails we roll back to the
    // previous session and avoid listing the rejected account.
    try {
      await context.read<LoginProvider>().onLoginSuccessFromSession(
        sessionInfo,
        login: widget.username,
        password2: widget.password,
        serverUrls: widget.serverUrl,
        databses: widget.database,
        sessionId: sessionId,
        usesTwoFactor: true,
        persistToPrefs: false,
      );
    } on PortalUserException catch (e) {
      // Thrown before any session state is touched, so there is nothing to
      // roll back. Handed to the caller, which shows the same Access Denied
      // notice a non-2FA sign-in gets — 2FA must not be a back door past it.
      _closeWith(TotpPortalUser(e.message));
      return false;
    } on DatabaseExpiredException {
      // Thrown first, before any session state is touched or persisted, so
      // there is nothing to roll back. No retyped code gets past an expired
      // subscription, so it is handed to the caller, which sends the user
      // back to the server screen where the database is chosen.
      _closeWith(const TotpDatabaseExpired());
      return false;
    } catch (_) {
      _showError('Invalid code or login failed. Please try again.');
      return false;
    }

    if (!mounted) return false;

    Future<void> rollback() async {
      if (previousSession != null) {
        await OdooSessionManager.updateSession(previousSession);
      } else {
        await OdooSessionManager.logout();
      }
    }

    final client = await OdooSessionManager.getClientEnsured();
    final eventInstalled = await isEventModuleInstalled(client);
    if (!eventInstalled) {
      await rollback();
      _closeWith(const TotpModuleMissing());
      return false;
    }

    // Two-factor is no back door past the access gate: an account with no
    // Event role is refused here exactly as it is on a plain sign-in.
    if (!await hasEventAccess(client)) {
      await rollback();
      _closeWith(const TotpNoEventAccess());
      return false;
    }

    final newSession = await OdooSessionManager.getCurrentSession();
    if (newSession == null) {
      await rollback();
      _showError('Sign-in could not be completed. Please try again.');
      return false;
    }

    // Module check passed, so the session is committed now — and only now,
    // so a rejected account never reaches the switcher or the disk.
    // `onLoginSuccessFromSession` above only set the in-memory session:
    // `storeAccount` registers it in the switcher, and `switchToAccount`
    // persists it in full (prefs plus the secure-storage password). That is
    // needed for a fresh sign-in as much as for Add Account — a session left
    // in memory only is gone on the next app start, and can't rebuild its
    // client once the in-memory one expires (a 2FA account can't fall back
    // to the password).
    await OdooSessionManager.setLastServerInfo(
      serverUrl: widget.serverUrl,
      database: widget.database,
    );
    await SessionService.instance.storeAccount(
      newSession,
      widget.password,
      markAsCurrent: true,
    );
    await SessionService.instance.switchToAccount(newSession);

    return true;
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  /// A failure no retyped code can get past on its own. Lifts any overlay so
  /// the screen shows [message]; the next Authenticate tap starts the whole
  /// flow over.
  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _blocked = true;
      _loading = false;
    });
  }

  /// The header and the code form, as one page that scrolls.
  Widget _buildContent(BuildContext context) {
    // On a phone on its side the header and the form no longer fit on screen
    // together, so they scroll as one compact page.
    if (context.isLandscape && context.isShortScreen) {
      return SizedBox.expand(
        child: LoginCompactBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(compact: true),
              const SizedBox(height: 12),
              _buildForm(),
            ],
          ),
        ),
      );
    }

    // Centred when it fits, scrollable when it doesn't (a short window, or
    // the keyboard taking half of it).
    const padding = 24.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(padding),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, constraints.maxHeight - padding * 2),
            ),
            child: ConstrainedContent(
              maxWidth: 400,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildForm(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.grey[50],
                  image: DecorationImage(
                    image: const AssetImage('assets/images/loginbg.png'),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      isDark
                          ? Colors.black.withValues(alpha: 1)
                          : Colors.white.withValues(alpha: 1),
                      BlendMode.dstATop,
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (_webViewFallback != null)
            TotpWebViewFallback(
              // Keyed on the controller so restarting the fallback builds a
              // fresh WebView bound to the new controller, rather than
              // leaving the old State attached to the old one.
              key: ObjectKey(_webViewFallback),
              controller: _webViewFallback!,
              serverUrl: widget.serverUrl,
              database: widget.database,
              username: widget.username,
              password: widget.password,
              onAuthenticated: _signInWithoutCode,
            ),

          _buildContent(context),

          // Above the content: its scroll view would otherwise swallow taps
          // that land on the arrow.
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              bottom: false,
              child: IgnorePointer(
                ignoring: _loading,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(32),
                    child: Container(
                      height: 64,
                      width: 64,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.arrow_back_ios,
                        color: _loading ? Colors.white54 : Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (_loading)
            Container(
              color: isDark ? Colors.black54 : Colors.white70,
              child: Center(
                child: LoadingWidget(
                  color: Theme.of(context).colorScheme.primary,
                  size: 60,
                  variant: LoadingVariant.fourRotatingDots,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader({bool compact = false}) {
    return Column(
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedTwoFactorAccess,
          color: Colors.white,
          size: compact ? 36 : 48,
        ),
        SizedBox(height: compact ? 12 : 24),
        Text(
          'Two-factor Authentication',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: compact ? 22 : 25,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: compact ? 8 : 16),
        Text(
          'To login, enter below the six-digit authentication code provided by your Authenticator app.',
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: Colors.white70,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        if (widget.serverUrl.isNotEmpty) ...[
          SizedBox(height: compact ? 8 : 16),
          Text(
            'Server: ${widget.serverUrl}',
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: Colors.white60,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _totpController,
            keyboardType: TextInputType.number,
            enabled: !_loading || !_verifying,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'TOTP is required';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _isButtonEnabled = value.trim().isNotEmpty;
                _formKey.currentState?.validate();
                if (_error != null) _error = null;
              });
            },
            cursorColor: Colors.black,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black,
            ),
            decoration: InputDecoration(
              hintText: 'Enter TOTP Code',
              hintStyle: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black.withValues(alpha: .4),
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(8.0),
                child: HugeIcon(icon: HugeIcons.strokeRoundedSmsCode, size: 10),
              ),
              prefixIconColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.disabled)
                    ? Colors.black26
                    : Colors.black54,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              errorStyle: const TextStyle(color: Colors.white),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red[900]!, width: 1.0),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),

          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _error != null ? 48 : 0,
            child: _error != null
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedAlertCircle,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: (_verifying || !_isButtonEnabled) ? null : _submitTotp,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _verifying
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Authenticating',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const LoadingWidget(color: Colors.white, size: 20),
                      ],
                    )
                  : Text(
                      'Authenticate',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
