import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/secure_storage_service.dart';
import '../utils/odoo_version.dart';

/// Extended session model with app-specific metadata
class AppSessionData {
  final OdooSession odooSession;
  final String password;
  final String serverUrl;
  final String database;
  final DateTime? expiresAt;
  final int? selectedCompanyId;
  final List<int> allowedCompanyIds;
  final bool isStockUser;
  final String? version;

  /// True when signing this account in required a second factor.
  ///
  /// Odoo will not hand back a usable session for such an account from the
  /// password alone, so a session carrying this flag must never be "refreshed"
  /// by replaying the password — expiry has to route back through the TOTP
  /// screen instead.
  final bool usesTwoFactor;

  const AppSessionData({
    required this.odooSession,
    required this.password,
    required this.serverUrl,
    required this.database,
    this.expiresAt,
    this.selectedCompanyId,
    this.allowedCompanyIds = const [],
    this.isStockUser = false,
    this.version,
    this.usesTwoFactor = false,
  });

  bool get isExpired =>
      expiresAt != null ? DateTime.now().isAfter(expiresAt!) : false;

  /// The server's major Odoo version, or null when this session was restored
  /// without one. Reads [version] first and falls back to the session's own
  /// `serverVersion`, because the two are written by different login paths.
  int? get odooMajorVersion =>
      OdooVersion.majorOf(version) ??
      OdooVersion.majorOf(odooSession.serverVersion);

  /// True when this session's server is Odoo [major] or newer.
  bool isOdooAtLeast(int major) {
    final current = odooMajorVersion;
    return current != null && current >= major;
  }

  String get userLogin => odooSession.userLogin;
  int get userId => odooSession.userId;
  String get sessionId => odooSession.id;
  int get companyId => selectedCompanyId ?? odooSession.companyId;

  AppSessionData copyWith({
    OdooSession? odooSession,
    String? password,
    String? serverUrl,
    String? database,
    DateTime? expiresAt,
    int? selectedCompanyId,
    List<int>? allowedCompanyIds,
    bool? isStockUser,
    String? version,
    bool? usesTwoFactor,
  }) {
    return AppSessionData(
      odooSession: odooSession ?? this.odooSession,
      password: password ?? this.password,
      serverUrl: serverUrl ?? this.serverUrl,
      database: database ?? this.database,
      expiresAt: expiresAt ?? this.expiresAt,
      selectedCompanyId: selectedCompanyId ?? this.selectedCompanyId,
      allowedCompanyIds: allowedCompanyIds ?? this.allowedCompanyIds,
      isStockUser: isStockUser ?? this.isStockUser,
      version: version ?? this.version,
      usesTwoFactor: usesTwoFactor ?? this.usesTwoFactor,
    );
  }

  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sessionId', odooSession.id);
    await prefs.setString('userLogin', odooSession.userLogin);
    await prefs.setString('database', database);
    await prefs.setString('serverUrl', serverUrl);
    await prefs.setInt('userId', odooSession.userId);
    await prefs.setBool('isStockUser', isStockUser);
    await prefs.setBool('usesTwoFactor', usesTwoFactor);
    // Normalised, and never `version.toString()` on a null: that persisted
    // the literal string "null", which then failed every version comparison
    // in the app as if the server had no version at all.
    await prefs.setString(
      'version',
      OdooVersion.normalize(version ?? odooSession.serverVersion),
    );

    if (expiresAt != null) {
      await prefs.setString('expiresAt', expiresAt!.toIso8601String());
    } else {
      await prefs.remove('expiresAt');
    }

    if (selectedCompanyId != null) {
      await prefs.setInt('selected_company_id', selectedCompanyId!);
    } else {
      await prefs.remove('selected_company_id');
    }

    await prefs.setStringList(
      'selected_allowed_company_ids',
      allowedCompanyIds.map((e) => e.toString()).toList(),
    );
    await prefs.setBool('isLoggedIn', true);

    await SecureStorageService.instance.storePassword(
      'session_password_username_${odooSession.userLogin}',
      password,
    );
    await SecureStorageService.instance.storePassword(
      'session_password_${odooSession.userId}',
      password,
    );
  }

  static Future<AppSessionData?> fromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      if (!isLoggedIn) return null;

      final sessionId = prefs.getString('sessionId');
      final userLogin = prefs.getString('userLogin');
      final database = prefs.getString('database');
      String? serverUrl = prefs.getString('serverUrl');
      final userId = prefs.getInt('userId');
      final isStockUser = prefs.getBool('isStockUser') ?? false;
      final usesTwoFactor = prefs.getBool('usesTwoFactor') ?? false;
      // Normalised on the way out too, so records written by an older build
      // of this app ("19.0", "saas~18.4", or "null") still compare correctly.
      final version = OdooVersion.normalize(prefs.getString('version'));
      if ([sessionId, userLogin, database, serverUrl, userId].contains(null)) {
        return null;
      }

      serverUrl = serverUrl!.trim();
      if (!serverUrl.startsWith('http://') &&
          !serverUrl.startsWith('https://')) {
        serverUrl = 'https://$serverUrl';
      }

      String? password = await SecureStorageService.instance.getPassword(
        'session_password_username_$userLogin',
      );
      if (password == null || password.isEmpty) {
        password = await SecureStorageService.instance.getPassword(
          'session_password_$userId',
        );
      }
      if (password == null || password.isEmpty) return null;

      DateTime? expiresAt;
      final expiresAtStr = prefs.getString('expiresAt');
      if (expiresAtStr != null && expiresAtStr.isNotEmpty) {
        try {
          expiresAt = DateTime.parse(expiresAtStr);
        } catch (_) {}
      }

      int? companyId;
      if (prefs.containsKey('selected_company_id')) {
        companyId = prefs.getInt('selected_company_id');
      }

      final allowedRaw =
          prefs.getStringList('selected_allowed_company_ids') ?? const [];
      final allowed = allowedRaw
          .map((e) => int.tryParse(e) ?? -1)
          .where((e) => e > 0)
          .toList();

      final odooSession = OdooSession(
        id: sessionId!,
        userId: userId!,
        partnerId: 0,
        companyId: companyId ?? 0,
        allowedCompanies: [],
        userLogin: userLogin!,
        userName: '',
        userLang: 'en_US',
        userTz: 'UTC',
        isSystem: false,
        dbName: database!,
        serverVersion: version,
      );

      return AppSessionData(
        odooSession: odooSession,
        password: password,
        serverUrl: serverUrl,
        database: database,
        expiresAt: expiresAt,
        selectedCompanyId: companyId,
        allowedCompanyIds: allowed,
        isStockUser: isStockUser,
        version: version,
        usesTwoFactor: usesTwoFactor,
      );
    } catch (_) {
      return null;
    }
  }
}
