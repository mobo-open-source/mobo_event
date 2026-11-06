import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../../app/app_entry.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/models/appsession.dart';
import '../../../core/routing/page_transition.dart';
import '../../../core/services/biometric_context_service.dart';
import '../../../core/services/event_access_gate.dart';
import '../../../core/services/event_module_gate.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/database_expiry.dart';
import '../../../shared/widgets/dialogs/access_denied_dialog.dart';
import '../../../shared/widgets/dialogs/blocking_notice_dialog.dart';
import '../../../shared/widgets/dialogs/common_dialog.dart';
import '../../../shared/widgets/dialogs/loading_dialog.dart';
import '../../../shared/widgets/dialogs/module_missing_dialog.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../../home/providers/home_provider.dart';
import '../../login/pages/credentials_screen.dart';
import '../../login/pages/otp_page.dart';
import '../../login/pages/server_setup_screen.dart';
import '../../login/utils/auth_failure.dart';
import '../providers/profile_provider.dart';

/// How a switch attempt ended — decided by [_performSwitch], presented by
/// [SwitchAccountWidget._switchAccount] once the loading dialog is gone.
enum _SwitchOutcome {
  switched,
  twoFactorRequired,
  needsSignIn,
  moduleMissing,
  portalUser,
  databaseExpired,
  noEventAccess,
  failed,
}

typedef _SwitchResult = ({_SwitchOutcome outcome, String? message});

/// Account switcher in the Profile screen's quick-actions card: the other
/// saved accounts, switching to or removing each, and Add Account.
class SwitchAccountWidget extends StatelessWidget {
  const SwitchAccountWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Consumer<SessionService>(
      builder: (context, sessionService, child) {
        final current = sessionService.currentSession;
        final otherAccounts = current == null
            ? const <Map<String, dynamic>>[]
            : sessionService.storedAccounts
                  .where((account) => !_isAccountOf(account, current))
                  .toList();
        final count = otherAccounts.length;

        return ExpansionTile(
          leading: HugeIcon(
            icon: HugeIcons.strokeRoundedUserSwitch,
            color: secondary,
          ),
          title: const Text(
            'Switch Accounts',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            count > 0
                ? '$count other account${count != 1 ? 's' : ''} available'
                : 'Add multiple accounts to switch quickly',
            style: TextStyle(color: secondary),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          children: [
            if (count == 0)
              const _EmptyAccounts()
            else
              for (final account in otherAccounts)
                _AccountTile(
                  key: ValueKey(_identityOf(account)),
                  account: account,
                  onSwitch: () =>
                      _switchAccount(context, account, sessionService),
                  onRemove: () =>
                      _removeAccount(context, account, sessionService),
                ),
            const SizedBox(height: 4),
            _AddAccountButton(current: current),
          ],
        );
      },
    );
  }

  Future<void> _switchAccount(
    BuildContext context,
    Map<String, dynamic> account,
    SessionService sessionService,
  ) async {
    final password = await sessionService.retrievePasswordWithMultiplePatterns(
      account,
    );
    if (!context.mounted) return;
    if (password == null || password.isEmpty) {
      _openSignIn(context, account);
      return;
    }

    final biometricContext = BiometricContextService();
    biometricContext.startAccountOperation('account_switch');

    LoadingDialog.show(context, message: 'Switching account…');
    final result = await _performSwitch(account, password, sessionService);
    if (context.mounted) LoadingDialog.hide(context);

    if (!context.mounted) {
      biometricContext.endAccountOperation('account_switch');
      return;
    }

    switch (result.outcome) {
      case _SwitchOutcome.switched:
        context.read<HomeProvider>().clearProvider();
        context.read<ProfileProvider>().resetState();
        Navigator.of(context).pushAndRemoveUntil(
          dynamicRoute(context, const AppEntry()),
          (_) => false,
        );
        biometricContext.endAccountOperation('account_switch');

      case _SwitchOutcome.twoFactorRequired:
        // TotpPage manages an operation named 'add_account' (it ends that
        // name on success and, as a back-out safety net, in its own
        // dispose()) — handing off under 'account_switch' instead would
        // leave that name in the active list forever, permanently disabling
        // the biometric lock.
        biometricContext.endAccountOperation('account_switch');
        biometricContext.startAccountOperation('add_account');
        final rejection = await Navigator.push<TotpRejection>(
          context,
          MaterialPageRoute(
            builder: (_) => TotpPage(
              serverUrl: account['serverUrl']?.toString() ?? '',
              database: account['database']?.toString() ?? '',
              username: _loginOf(account),
              password: password,
              addaccount: true,
            ),
          ),
        );
        if (!context.mounted) return;
        switch (rejection) {
          case TotpModuleMissing():
            await showModuleMissingDialog(context, actionLabel: 'OK');
          case TotpPortalUser(:final message):
            await showAccessDeniedDialog(context, message: message);
          case TotpDatabaseExpired():
            CustomSnackbar.showError(context, DatabaseExpiredException.message);
          case TotpNoEventAccess():
            await showAccessDeniedDialog(
              context,
              denial: AccessDenial.noEventAccess,
            );
          case null:
            break;
        }

      case _SwitchOutcome.needsSignIn:
        biometricContext.endAccountOperation('account_switch');
        _openSignIn(context, account);

      case _SwitchOutcome.moduleMissing:
        biometricContext.endAccountOperation('account_switch');
        await showModuleMissingDialog(context, actionLabel: 'OK');

      case _SwitchOutcome.portalUser:
        biometricContext.endAccountOperation('account_switch');
        await showAccessDeniedDialog(
          context,
          message: result.message ?? PortalUserException.portalUserMessage,
        );

      case _SwitchOutcome.databaseExpired:
        biometricContext.endAccountOperation('account_switch');
        CustomSnackbar.showError(
          context,
          result.message ?? DatabaseExpiredException.message,
        );

      case _SwitchOutcome.noEventAccess:
        biometricContext.endAccountOperation('account_switch');
        await showAccessDeniedDialog(
          context,
          denial: AccessDenial.noEventAccess,
        );

      case _SwitchOutcome.failed:
        biometricContext.endAccountOperation('account_switch');
        await showBlockingNoticeDialog(
          context,
          title: 'Switch Failed',
          message:
              result.message ??
              'Failed to switch account. Please try again or re-add this '
                  'account.',
        );
    }
  }

  /// Makes [account] the active session, or reports why it couldn't.
  ///
  /// Whatever happens, a failure leaves the account that was active when the
  /// user tapped Switch in place — nothing here may leave the app signed in
  /// as one account while the screen still shows another.
  Future<_SwitchResult> _performSwitch(
    Map<String, dynamic> account,
    String password,
    SessionService sessionService,
  ) async {
    final previousSession = sessionService.currentSession;

    Future<void> rollback() async {
      if (previousSession != null) {
        await OdooSessionManager.updateSession(previousSession);
      }
    }

    try {
      // Reinstating the saved session cookie is tried first: a fresh
      // password login makes Odoo re-issue its 2FA challenge even for an
      // account that already passed it, and the cookie avoids asking for the
      // code again. It falls back to a full login (and, if needed, the code
      // screen) when there is no saved cookie or the server has dropped it.
      AppSessionData? newSession;
      final restored = sessionService.buildSessionFromStoredAccount(
        account,
        password,
      );
      if (restored != null) {
        await sessionService.updateSessionDirectly(restored);
        if (await sessionService.isRestoredSessionLive(restored.userId)) {
          // A reinstated cookie never goes through `authenticate()`, so it
          // needs its own expiry check. The catch below puts the previous
          // account back before this surfaces.
          final client = await OdooSessionManager.getClientEnsured();
          if (await DatabaseExpiry.isExpired(client)) {
            throw const DatabaseExpiredException();
          }
          newSession = restored;
        } else {
          // Put the previous account back before the login below runs any
          // RPCs, so they are never scoped to a session that is gone.
          await rollback();
        }
      }

      newSession ??= await OdooSessionManager.authenticate(
        serverUrl: account['serverUrl']?.toString() ?? '',
        database: account['database']?.toString() ?? '',
        username: _loginOf(account),
        password: password,
      );
      if (newSession == null) {
        await rollback();
        return (outcome: _SwitchOutcome.needsSignIn, message: null);
      }

      final client = await OdooSessionManager.getClientEnsured();
      if (!await isEventModuleInstalled(client)) {
        await rollback();
        return (outcome: _SwitchOutcome.moduleMissing, message: null);
      }

      // A saved account can lose its Event role on the server after it was
      // added, so this is asked on every switch, not only when adding.
      if (!await hasEventAccess(client)) {
        await rollback();
        return (outcome: _SwitchOutcome.noEventAccess, message: null);
      }

      final switched = newSession.copyWith(
        selectedCompanyId: newSession.companyId,
      );
      await OdooSessionManager.updateSession(switched);
      sessionService.updateSession(switched);

      // A switch onto a restored cookie never otherwise goes through
      // `storeAccount`, so its switcher entry (name, avatar, the cookie
      // itself) would go stale.
      await sessionService.storeAccount(switched, password);
      return (outcome: _SwitchOutcome.switched, message: null);
    } catch (e) {
      await rollback();

      // By type, ahead of every check below: the message says "database",
      // and the classifier's text matching must never get to read it.
      if (e is DatabaseExpiredException) {
        return (
          outcome: _SwitchOutcome.databaseExpired,
          message: DatabaseExpiredException.message,
        );
      }
      if (isTwoFactorError(e)) {
        return (outcome: _SwitchOutcome.twoFactorRequired, message: null);
      }
      if (e is PortalUserException) {
        return (outcome: _SwitchOutcome.portalUser, message: e.message);
      }
      if (classifyAuthFailure(e) == AuthFailure.invalidCredentials) {
        // The stored password no longer works (changed on the server).
        return (outcome: _SwitchOutcome.needsSignIn, message: null);
      }
      return (
        outcome: _SwitchOutcome.failed,
        message: authFailureMessage(
          e,
          fallback:
              'Failed to switch account. Please try again or re-add this '
              'account.',
        ),
      );
    }
  }

  /// No usable stored password — never saved, or changed on the server — so
  /// it has to be typed again. The sign-in screen restores the current
  /// account if that attempt fails, so opening it is always safe.
  void _openSignIn(BuildContext context, Map<String, dynamic> account) {
    Navigator.push(
      context,
      dynamicRoute(
        context,
        CredentialsScreen(
          url: account['serverUrl']?.toString() ?? '',
          database: account['database']?.toString() ?? '',
          prefilledUsername: _loginOf(account),
        ),
      ),
    );
  }

  Future<void> _removeAccount(
    BuildContext context,
    Map<String, dynamic> account,
    SessionService sessionService,
  ) async {
    final name = _displayNameOf(account);
    final confirmed = await CommonDialog.confirm(
      context,
      title: 'Remove Account',
      message:
          'Remove $name from your saved accounts? You can add it again at '
          'any time.',
      confirmText: 'Remove',
    );
    if (confirmed != true || !context.mounted) return;

    // Matched on the full identity, not the user id alone: the same id is
    // routinely reused across servers and databases (every admin is 2).
    final identity = _identityOf(account);
    final index = sessionService.storedAccounts.indexWhere(
      (stored) => _identityOf(stored) == identity,
    );
    if (index == -1) return;

    await sessionService.removeStoredAccount(index);
    if (!context.mounted) return;
    CustomSnackbar.show(
      context: context,
      title: 'Success',
      message: 'Account $name removed',
      type: SnackbarType.success,
    );
  }
}

/// Whether [account] (a stored switcher record) is the session [session].
bool _isAccountOf(Map<String, dynamic> account, AppSessionData session) {
  return account['userId']?.toString() == session.userId.toString() &&
      account['database']?.toString() == session.database &&
      _sameServer(account['serverUrl']?.toString(), session.serverUrl);
}

/// Compares server URLs the way the rest of the login flow treats them —
/// ignoring case and a trailing slash — so the active account is never
/// listed as an "other" account just because it was saved with a slash.
bool _sameServer(String? a, String? b) {
  String normalize(String? url) {
    var value = (url ?? '').trim().toLowerCase();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  return normalize(a) == normalize(b);
}

String _identityOf(Map<String, dynamic> account) =>
    '${account['userId']}|${account['serverUrl']}|${account['database']}';

/// The login to authenticate with. `userName` is the display name, not a
/// login, so it is never used here.
String _loginOf(Map<String, dynamic> account) =>
    account['username']?.toString() ?? account['email']?.toString() ?? '';

String _displayNameOf(Map<String, dynamic> account) {
  for (final key in const ['userName', 'name', 'username']) {
    final value = account[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return 'Unknown User';
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedUserAdd01,
              size: 22,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No Other Accounts',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add multiple accounts to switch between them quickly',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _AccountTile extends StatefulWidget {
  const _AccountTile({
    super.key,
    required this.account,
    required this.onSwitch,
    required this.onRemove,
  });

  final Map<String, dynamic> account;
  final Future<void> Function() onSwitch;
  final VoidCallback onRemove;

  @override
  State<_AccountTile> createState() => _AccountTileState();
}

class _AccountTileState extends State<_AccountTile> {
  /// Whether a password is stored for this account; null while that is being
  /// looked up. Without one, switching means typing the password again.
  bool? _hasPassword;

  /// Guards against a second tap starting a second switch while the first
  /// is still on its way to showing the loading dialog.
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _lookUpPassword();
  }

  @override
  void didUpdateWidget(covariant _AccountTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.account, widget.account)) _lookUpPassword();
  }

  Future<void> _lookUpPassword() async {
    final password = await SessionService.instance
        .retrievePasswordWithMultiplePatterns(widget.account);
    if (!mounted) return;
    setState(() => _hasPassword = password != null && password.isNotEmpty);
  }

  Future<void> _handleSwitch() async {
    if (_switching) return;
    _switching = true;
    try {
      await widget.onSwitch();
    } finally {
      _switching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final account = widget.account;
    final database = account['database']?.toString() ?? '';
    final host = Uri.tryParse(account['serverUrl']?.toString() ?? '')?.host;
    final needsSignIn = _hasPassword == false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleSwitch,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
            child: Row(
              children: [
                _AccountAvatar(account: account),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _displayNameOf(account),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        host == null || host.isEmpty
                            ? database
                            : '$database',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      if (needsSignIn) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 12,
                              color: StatusColors.orange,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Needs re-authentication',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: StatusColors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                PopupMenuButton<String>(
                  position: PopupMenuPosition.under,
                  icon: Icon(
                    Icons.more_vert,
                    size: 20,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  onSelected: (value) {
                    if (value == 'remove') widget.onRemove();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'remove',
                      child: Text(
                        'Remove',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.account});

  final Map<String, dynamic> account;

  static const double _size = 40;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
          width: 1.5,
        ),
      ),
      child: ClipOval(child: _image(isDark)),
    );
  }

  Widget _image(bool isDark) {
    final fallback = _Initials(account: account, isDark: isDark);

    final imageBase64 = account['imageBase64']?.toString();
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(imageBase64),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => fallback,
        );
      } catch (_) {
        // Malformed data falls through to the server copy.
      }
    }

    final serverUrl = account['serverUrl']?.toString();
    final userId = account['userId']?.toString();
    if (serverUrl == null || serverUrl.isEmpty || userId == null) {
      return fallback;
    }

    // A stable URL, so the image is served from cache on every rebuild
    // rather than re-downloaded each time the switcher repaints.
    return CachedNetworkImage(
      imageUrl:
          '$serverUrl/web/image?model=res.users&id=$userId&field=image_128',
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.account, required this.isDark});

  final Map<String, dynamic> account;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final parts = _displayNameOf(
      account,
    ).split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? 'U'
        : parts.take(2).map((part) => part[0].toUpperCase()).join();

    return Container(
      color: isDark ? Colors.grey[700] : Colors.grey[200],
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.grey[200] : Colors.grey[700],
        ),
      ),
    );
  }
}

class _AddAccountButton extends StatelessWidget {
  const _AddAccountButton({required this.current});

  /// The active session, whose server and database the new account starts
  /// from — adding a second account on the same server is the common case.
  final AppSessionData? current;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            dynamicRoute(
              context,
              ServerSetupScreen(
                isAddingAccount: true,
                initialUrl: current?.serverUrl,
                initialDatabase: current?.database,
              ),
            ),
          );
        },
        icon: const HugeIcon(
          icon: HugeIcons.strokeRoundedUserAdd01,
          size: 18,
          color: AppTheme.white,
        ),
        label: const Text(
          'Add Account',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: AppTheme.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
