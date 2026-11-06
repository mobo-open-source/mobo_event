import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

import '../models/appsession.dart';
import '../utils/odoo_binary.dart';
import '../utils/odoo_version.dart';
import 'odoo_session_manager.dart';
import 'secure_storage_service.dart';

class SessionService extends ChangeNotifier {
  static final SessionService instance = SessionService._internal();
  factory SessionService() => instance;
  SessionService._internal();

  AppSessionData? _currentSession;
  bool _isInitialized = false;
  List<Map<String, dynamic>> _storedAccounts = [];

  AppSessionData? get currentSession => _currentSession;
  bool get isInitialized => _isInitialized;
  bool get hasValidSession => _currentSession != null;
  List<Map<String, dynamic>> get storedAccounts => _storedAccounts;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    OdooSessionManager.setSessionCallbacks(
      onSessionUpdated: (sessionModel) {
        updateSession(sessionModel);
      },
      onSessionCleared: () {
        clearSession();
      },
    );

    _currentSession = await OdooSessionManager.getCurrentSession();

    await _loadStoredAccounts();

    await _migratePasswordsToSecureStorage();

    if (_currentSession != null) {
      await _autoStoreCurrentSession();
    }

    _isInitialized = true;

    notifyListeners();
  }

  void updateSession(AppSessionData newSession) {
    _currentSession = newSession;
    notifyListeners();
  }

  void clearSession() {
    _currentSession = null;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await OdooSessionManager.logout();

      await _clearStoredAccountsData();

      await _clearPasswordCaches();

      clearSession();
    } catch (_) {}
  }

  Future<void> _loadStoredAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> storedAccountsJson =
          prefs.getStringList('stored_accounts') ?? [];

      _storedAccounts = storedAccountsJson
          .map((json) {
            try {
              final decoded = Map<String, dynamic>.from(jsonDecode(json));
              return decoded;
            } catch (_) {
              return null;
            }
          })
          .where((account) => account != null)
          .cast<Map<String, dynamic>>()
          .toList();

      await _cleanupDuplicateAccounts();

      notifyListeners();
    } catch (_) {
      _storedAccounts = [];
    }
  }

  Future<void> _autoStoreCurrentSession() async {
    if (_currentSession == null) return;

    final currentExists = _storedAccounts.any(
      (account) =>
          account['userId'] == _currentSession!.userId.toString() &&
          account['serverUrl'] == _currentSession!.serverUrl &&
          account['database'] == _currentSession!.database,
    );

    if (!currentExists) {
      await storeAccount(_currentSession!, '');
    }
  }

  Future<void> _cleanupDuplicateAccounts() async {
    final uniqueAccounts = <String, Map<String, dynamic>>{};

    for (final account in _storedAccounts) {
      final userId = account['userId']?.toString() ?? '';
      final serverUrl = account['serverUrl']?.toString() ?? '';
      final database = account['database']?.toString() ?? '';

      if (userId.isEmpty || serverUrl.isEmpty || database.isEmpty) {
        continue;
      }

      final key = '${userId}_${serverUrl}_$database';

      if (!uniqueAccounts.containsKey(key)) {
        uniqueAccounts[key] = account;
      } else {
        final existing = uniqueAccounts[key]!;
        final currentHasPassword =
            account['password']?.toString().isNotEmpty == true;
        final existingHasPassword =
            existing['password']?.toString().isNotEmpty == true;

        if (currentHasPassword && !existingHasPassword) {
          uniqueAccounts[key] = account;
        }
      }
    }

    final originalCount = _storedAccounts.length;
    _storedAccounts = uniqueAccounts.values.toList();

    if (_storedAccounts.length != originalCount) {
      await _saveStoredAccountsWithRetry();
    }
  }

  Future<void> storeAccount(
    AppSessionData session,
    String password, {
    bool markAsCurrent = true,
  }) async {
    try {
      String? imageBase64;
      String userDisplayName = session.userLogin;

      try {
        final client = await OdooSessionManager.getClient();

        if (client != null && session.userId != null) {
          final userDetails = await client.callKw({
            'model': 'res.users',
            'method': 'read',
            'args': [
              [session.userId],
              ['name', 'image_1920'],
            ],
            'kwargs': {},
          });

          if (userDetails is List && userDetails.isNotEmpty) {
            final user = userDetails.first as Map;
            final n = user['name'];
            if (n != null && n != false) {
              userDisplayName = n.toString();
            }
            // Base64 text through Odoo 19, a {content, size} object on 20 —
            // `toString()` on the object cached its Dart representation as the
            // "photo".
            imageBase64 = OdooBinary.base64(user['image_1920']);
          }
        }
      } catch (_) {}

      // Create account data (WITHOUT password - stored securely)
      final accountData = {
        'id': session.userId.toString(),
        'name': userDisplayName,
        'email': session.userLogin,
        'url': session.serverUrl.trim(),
        'database': session.database,
        'username': session.userLogin,
        'isCurrent': markAsCurrent,
        'lastLogin': DateTime.now().toIso8601String(),
        'imageBase64': imageBase64?.isNotEmpty == true ? imageBase64 : null,
        'userId': session.userId.toString(),
        'userName': userDisplayName,
        'serverUrl': session.serverUrl,
        'sessionId': session.sessionId,

        // Everything below is what lets a later switch-to reconstruct a full
        // OdooSession from this stored record and try the saved cookie
        // directly (see [buildSessionFromStoredAccount]) instead of always
        // re-authenticating with the password — which for a 2FA account means
        // redoing the whole TOTP flow on every switch.
        //
        // The company context also travels with the account, so the first
        // RPCs after a switch are scoped to the account being switched *to*
        // rather than to whatever the previous account had selected.
        'partnerId': session.odooSession.partnerId,
        'companyId': session.odooSession.companyId,
        'selectedCompanyId': session.selectedCompanyId,
        'allowedCompanyIds': session.allowedCompanyIds,
        'userLang': session.odooSession.userLang,
        'userTz': session.odooSession.userTz,
        'isSystem': session.odooSession.isSystem,

        // Stored as the bare major, the same form every login path now
        // saves, so a switch back to this account compares the same value
        // the session itself carries.
        'serverVersion': OdooVersion.normalize(
          session.version ?? session.odooSession.serverVersion,
        ),
        'usesTwoFactor': session.usesTwoFactor,

        // The whole Odoo session, so a switch can restore the live cookie
        // instead of re-authenticating — the only way an account protected
        // by a second factor can be switched to without redoing the TOTP
        // flow.
        'session': jsonEncode(session.odooSession.toJson()),
      };

      if (markAsCurrent) {
        for (var account in _storedAccounts) {
          account['isCurrent'] = false;
        }
      }

      final existingIndex = _storedAccounts.indexWhere(
        (account) =>
            account['id'] == accountData['id'] &&
            account['url'] == accountData['url'] &&
            account['database'] == accountData['database'],
      );

      if (existingIndex != -1) {
        _storedAccounts[existingIndex] = accountData;
      } else {
        _storedAccounts.insert(0, accountData);
      }

      await _saveStoredAccountsWithRetry();

      if (password.isNotEmpty) {
        await _storePasswordWithMultiplePatterns(session, password);
      }

      notifyListeners();
    } catch (_) {
      rethrow;
    }
  }

  /// Brings the active account's switcher record (display name and avatar)
  /// in line with its profile.
  ///
  /// The record is otherwise only written at sign-in, add and switch, so a
  /// name or photo edited in the profile would keep showing the old values in
  /// the account switcher — which is where this account appears as soon as
  /// the user switches to another one. Called after every profile fetch, not
  /// only after a save, so an edit made elsewhere (in Odoo itself) is caught
  /// up the next time the profile loads.
  Future<void> updateCurrentAccountDisplay({
    String? name,
    String? imageBase64,
  }) async {
    final session = _currentSession;
    if (session == null) return;
    if (name == null && imageBase64 == null) return;

    String normalizeUrl(String? url) {
      var value = (url ?? '').trim().toLowerCase();
      while (value.endsWith('/')) {
        value = value.substring(0, value.length - 1);
      }
      return value;
    }

    final index = _storedAccounts.indexWhere(
      (account) =>
          account['userId']?.toString() == session.userId.toString() &&
          account['database']?.toString() == session.database &&
          normalizeUrl(account['serverUrl']?.toString()) ==
              normalizeUrl(session.serverUrl),
    );
    if (index == -1) return;

    final current = _storedAccounts[index];
    final unchanged =
        (name == null || current['name'] == name) &&
        (imageBase64 == null || current['imageBase64'] == imageBase64);
    if (unchanged) return;

    if (name != null) {
      current['name'] = name;
      current['userName'] = name;
    }
    if (imageBase64 != null) {
      current['imageBase64'] = imageBase64;
    }

    await _saveStoredAccountsWithRetry();
    notifyListeners();
  }

  /// Rebuilds a full [AppSessionData] from a stored account record, or null
  /// when the record is too old or incomplete to reconstruct one.
  ///
  /// This is what lets a switch skip re-authentication: the saved session
  /// cookie is reinstated directly, and only if the server rejects it (see
  /// [isRestoredSessionLive]) does the caller fall back to a password login.
  AppSessionData? buildSessionFromStoredAccount(
    Map<String, dynamic> account,
    String password,
  ) {
    try {
      final sessionId = account['sessionId']?.toString();
      final userLogin =
          account['username']?.toString() ?? account['userName']?.toString();
      final database = account['database']?.toString();
      final serverUrl = account['serverUrl']?.toString();
      final userId = int.tryParse(account['userId']?.toString() ?? '');

      if (sessionId == null ||
          sessionId.isEmpty ||
          userLogin == null ||
          userLogin.isEmpty ||
          database == null ||
          database.isEmpty ||
          serverUrl == null ||
          serverUrl.isEmpty ||
          userId == null ||
          password.isEmpty) {
        return null;
      }

      final partnerId =
          int.tryParse(account['partnerId']?.toString() ?? '') ?? 0;
      final companyId =
          int.tryParse(account['companyId']?.toString() ?? '') ?? 0;
      final selectedCompanyId = int.tryParse(
        account['selectedCompanyId']?.toString() ?? '',
      );
      final allowedCompanyIds =
          (account['allowedCompanyIds'] as List?)
              ?.map((e) => int.tryParse(e.toString()) ?? -1)
              .where((e) => e > 0)
              .toList() ??
          const <int>[];

      final odooSession =
          _restoreStoredSession(
            account['session'],
            userId: userId,
            database: database,
            sessionId: sessionId,
          ) ??
          OdooSession(
            id: sessionId,
            userId: userId,
            partnerId: partnerId,
            companyId: companyId,
            allowedCompanies: const [],
            userLogin: userLogin,
            userName:
                account['userName']?.toString() ??
                account['name']?.toString() ??
                userLogin,
            userLang: account['userLang']?.toString() ?? 'en_US',
            userTz: account['userTz']?.toString() ?? 'UTC',
            isSystem: account['isSystem'] == true,
            dbName: database,
            serverVersion: OdooVersion.normalize(account['serverVersion']),
          );

      return AppSessionData(
        odooSession: odooSession,
        password: password,
        serverUrl: serverUrl,
        database: database,
        selectedCompanyId: selectedCompanyId,
        allowedCompanyIds: allowedCompanyIds,
        version: OdooVersion.normalize(account['serverVersion']),
        usesTwoFactor: account['usesTwoFactor'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  /// Rebuilds a stored account's [OdooSession] from its saved payload, or null
  /// when the record predates it, cannot be parsed, or names a different
  /// account than the record's own flat fields — an identity guard, so a
  /// corrupted record can never hand back someone else's session.
  static OdooSession? _restoreStoredSession(
    Object? raw, {
    required int userId,
    required String database,
    required String sessionId,
  }) {
    if (raw is! String || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final restored = OdooSession.fromJson(Map<String, dynamic>.from(decoded));
      if (restored.userId != userId || restored.dbName != database) return null;
      return restored.id == sessionId
          ? restored
          : restored.updateSessionId(sessionId);
    } catch (_) {
      return null;
    }
  }

  /// Cheap RPC probe confirming a restored session cookie is still accepted by
  /// the server, without doing a password login.
  ///
  /// Must be called only after the session under test has been made active
  /// (via [updateSessionDirectly]), since it always probes the *current*
  /// session. Calls `client.callKw` directly rather than a helper that
  /// auto-retries auth failures with a password login — that would silently
  /// redo the re-authentication this probe exists to avoid.
  Future<bool> isRestoredSessionLive(int userId) async {
    try {
      final client = await OdooSessionManager.getClientEnsured();
      final result = await client.callKw({
        'model': 'res.users',
        'method': 'read',
        'args': [
          [userId],
          ['id'],
        ],
        'kwargs': {},
      });
      return result is List && result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _storePasswordWithMultiplePatterns(
    AppSessionData session,
    String password,
  ) async {
    if (password.isEmpty) return;

    try {
      final secureStorage = SecureStorageService.instance;

      // Store password with multiple patterns for reliable retrieval
      await secureStorage.storePassword(
        'password_${session.userId}_${session.database}',
        password,
      );
      await secureStorage.storePassword(
        'password_${session.userLogin}_${session.database}',
        password,
      );
    } catch (_) {}
  }

  Future<String?> retrievePasswordWithMultiplePatterns(
    Map<String, dynamic> accountData,
  ) async {
    try {
      final secureStorage = SecureStorageService.instance;
      final userId = accountData['id'] ?? accountData['userId'];
      final username = accountData['username'] ?? accountData['email'];
      final database = accountData['database'];

      List<String> passwordKeys = [
        'password_${userId}_$database',
        'password_${username}_$database',
      ];

      for (String key in passwordKeys) {
        final password = await secureStorage.getPassword(key);
        if (password != null && password.isNotEmpty) {
          return password;
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveStoredAccountsWithRetry() async {
    int maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final prefs = await SharedPreferences.getInstance();

        final updatedAccountsJson = _storedAccounts
            .map((account) => jsonEncode(account))
            .toList();

        await prefs.setStringList('stored_accounts', updatedAccountsJson);

        return;
      } catch (_) {
        if (attempt != maxRetries) {
          await Future.delayed(Duration(milliseconds: 100 * attempt));
        }
      }
    }
  }

  Future<void> removeStoredAccount(int accountIndex) async {
    if (accountIndex < 0 || accountIndex >= _storedAccounts.length) {
      return;
    }

    final removed = _storedAccounts.removeAt(accountIndex);
    await _saveStoredAccountsWithRetry();
    await _forgetPasswordsOf(removed);
    notifyListeners();
  }

  /// Deletes a removed account's saved password, so removing an account
  /// actually forgets its credentials.
  ///
  /// The password keys carry only the user and the database — not the server
  /// — so a key is kept while any remaining account (or the active session)
  /// still resolves to it; the same user on the same database name on two
  /// servers would otherwise lose the password of the one still listed.
  Future<void> _forgetPasswordsOf(Map<String, dynamic> account) async {
    final database = account['database']?.toString() ?? '';
    if (database.isEmpty) return;

    Set<String> keysOf(Map<String, dynamic> a) => {
      'password_${a['id'] ?? a['userId']}_${a['database']}',
      'password_${a['username'] ?? a['email']}_${a['database']}',
    };

    final stillUsed = <String>{
      for (final other in _storedAccounts) ...keysOf(other),
      if (_currentSession != null) ...{
        'password_${_currentSession!.userId}_${_currentSession!.database}',
        'password_${_currentSession!.userLogin}_${_currentSession!.database}',
      },
    };

    for (final key in keysOf(account).difference(stillUsed)) {
      try {
        await SecureStorageService.instance.deletePassword(key);
      } catch (_) {
        // A key that can't be deleted only means a stale password lingers.
      }
    }
  }

  Future<bool> updateSessionDirectly(AppSessionData newSession) async {
    try {
      _currentSession = newSession;

      await OdooSessionManager.updateSession(newSession);

      notifyListeners();

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> switchToAccount(AppSessionData newSession) async {
    return await updateSessionDirectly(newSession);
  }

  /// Legacy method for compatibility with login provider
  Future<void> updateAccountCredentials(
    String username,
    String password,
  ) async {
    if (_currentSession != null) {
      await _storePasswordWithMultiplePatterns(_currentSession!, password);
    }
  }

  Future<void> _clearStoredAccountsData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('stored_accounts');
      _storedAccounts = [];
    } catch (_) {}
  }

  Future<void> _clearPasswordCaches() async {
    try {
      await SecureStorageService.instance.clearAll();
    } catch (_) {}
  }

  /// Migrate passwords from SharedPreferences to secure storage
  Future<void> _migratePasswordsToSecureStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (prefs.getBool('passwords_migrated') == true) {
        return;
      }

      final secureStorage = SecureStorageService.instance;

      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        if (key.startsWith('password_')) {
          final password = prefs.getString(key);
          if (password != null && password.isNotEmpty) {
            await secureStorage.storePassword(key, password);
            await prefs.remove(key);
          }
        }
      }

      await prefs.setBool('passwords_migrated', true);
    } catch (_) {}
  }
}
