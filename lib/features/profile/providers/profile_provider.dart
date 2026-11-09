import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/utils/odoo_binary.dart';
import '../../../core/utils/odoo_compat.dart';
import '../../../core/utils/odoo_version.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../../core/services/session_service.dart';
import '../../../core/utils/base64_utils.dart';

class ProfileProvider extends ChangeNotifier {
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  Uint8List? _userAvatar;
  String? _error;
  bool _hasInternet = true;
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _states = [];
  bool _isLoadingCountries = false;
  bool _isLoadingStates = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// Stored per account (see [_cacheKey]): this provider outlives every login
  /// and switch, and one shared key painted the previous account's name and
  /// photo for a moment after every switch.
  static const String _cacheKeyUser = 'user_profile';

  bool get isLoading => _isLoading;
  Map<String, dynamic>? get userData => _userData;
  Uint8List? get userAvatar => _userAvatar;
  String? get userAvatarBase64 => OdooBinary.base64(_userData?['image_1920']);

  String? get error => _error;
  bool get hasInternet => _hasInternet;
  List<Map<String, dynamic>> get countries => _countries;
  List<Map<String, dynamic>> get states => _states;
  bool get isLoadingCountries => _isLoadingCountries;
  bool get isLoadingStates => _isLoadingStates;

  String normalizeForEdit(dynamic value) {
    if (value == null) return '';
    if (value is bool) return value ? 'true' : '';
    final s = value.toString().trim();
    return (s.toLowerCase() == 'false' || s.isEmpty) ? '' : s;
  }

  /// The `res.users` fields the profile read falls back to when the server's
  /// own field list cannot be discovered.
  ///
  /// Every one of these is either a plain column or a partner-delegated field
  /// present on 16 through 19, so this list works on any supported release.
  static const List<String> _fallbackUserFields = [
    'name',
    'login',
    'email',
    'website',
    'function',
    'image_1920',
    'company_id',
    'partner_id',
  ];

  /// The `res.partner` fields the profile wants, in read order. Only the ones
  /// the connected server actually defines are requested — Odoo rejects the
  /// *entire* read for one unrecognized field, which would silently cost the
  /// address and phone as well.
  static const List<String> _wantedPartnerFields = [
    // `phone` is deliberately absent: it is resolved per server and may live
    // on res.users instead — see [_getPhoneFieldName].
    'street',
    // Read even though only the address dialog shows it: that dialog writes
    // the whole address back, so a street2 that was never read would be
    // written back as false and wipe the server's value.
    'street2',
    'city',
    'zip',
    'state_id',
    'country_id',
    // Backs the Related Company row. Read here rather than through a second
    // call so it is present as soon as the profile is.
    'parent_id',
  ];

  /// Which model owns each row the profile screen can show, so availability is
  /// checked against the schema of the model that actually stores it.
  static const Map<String, String> _profileFieldOwner = {
    'name': 'res.users',
    'login': 'res.users',
    'email': 'res.users',
    'website': 'res.users',
    'function': 'res.users',
    'image_1920': 'res.users',
    'company_id': 'res.users',
    // `phone` and `mobile` are absent on purpose: neither has a fixed owner,
    // so both are gated on their own resolution instead.
    'street': 'res.partner',
    'street2': 'res.partner',
    'city': 'res.partner',
    'zip': 'res.partner',
    'state_id': 'res.partner',
    'country_id': 'res.partner',
    'parent_id': 'res.partner',
  };

  List<String>? _profileUserFieldsCache;
  String? _profileFieldsAccountKey;
  Set<String> _discoveredUserFields = {};
  Set<String> _discoveredPartnerFields = {};
  bool _userFieldsDiscovered = false;
  bool _partnerFieldsDiscovered = false;

  /// Which field holds the mobile number on this server, or null when it has
  /// none. Read together with [_mobileFieldModel], which says where it lives.
  String? _partnerMobileFieldNameCache;

  /// Which model [_partnerMobileFieldNameCache] lives on: `res.partner`, or
  /// `res.users` when resolution fell back to `hr`'s field. Null exactly when
  /// the name cache is null.
  String? _mobileFieldModel;

  /// The account the mobile-field resolution was made for.
  ///
  /// This provider is created once in `main.dart` and outlives every login and
  /// account switch, so a name resolved for one server must not be reused for
  /// another. Without this key, switching from an Odoo 17/18 account (where
  /// `res.partner.mobile` exists) to an Odoo 19 one (where it was removed)
  /// kept sending the stale `mobile` field name, and Odoo rejects the whole
  /// call for an unrecognized field — wiping out phone/street/city/zip too.
  String? _mobileFieldAccountKey;

  bool _mobileFieldResolved = false;

  /// What the connected server's *version* says about `res.partner.mobile`,
  /// independent of the field probe: true on 16/17/18, false on 19. Stands in
  /// until the probe answers, so the Mobile row follows the release rather
  /// than defaulting to "assume it exists" on a server where it does not.
  bool? _versionSaysMobileExists;

  /// Which field holds the phone number, and on which model — the same pair as
  /// the mobile cache above. See [_getPhoneFieldName].
  String? _phoneFieldName;
  String? _phoneFieldModel;
  String? _phoneFieldAccountKey;
  bool _phoneFieldResolved = false;

  /// Whether the connected server has anywhere to keep a phone number.
  ///
  /// True until the probe has run: `res.partner.phone` exists on every
  /// supported release, so the row is worth showing while the answer is still
  /// unknown rather than blinking out and back.
  bool get hasPhoneField =>
      _phoneFieldResolved ? _phoneFieldName != null : true;

  /// Whether the connected server has any field to hold a mobile number.
  ///
  /// Null until the first fetch has resolved it. False means Odoo 19 with no
  /// custom replacement, where the screen hides its Mobile row rather than
  /// offering an edit the server would drop.
  bool? get hasMobileField => _mobileFieldResolved
      ? _partnerMobileFieldNameCache != null
      : _versionSaysMobileExists;

  /// Whether the connected server exposes [field], so the screen can leave the
  /// row out entirely instead of showing an edit the server cannot store.
  ///
  /// True while discovery has not run for the owning model: a cached profile
  /// then paints its rows immediately rather than flashing them away and back.
  bool isProfileFieldAvailable(String field) {
    if (field == 'mobile') return hasMobileField ?? true;
    // Not checked against the res.partner schema: it may have resolved to
    // `hr`'s res.users.work_phone instead — see [_getPhoneFieldName].
    if (field == 'phone') return hasPhoneField;
    switch (_profileFieldOwner[field]) {
      case 'res.users':
        return _userFieldsDiscovered
            ? _discoveredUserFields.contains(field)
            : true;
      case 'res.partner':
        return _partnerFieldsDiscovered
            ? _discoveredPartnerFields.contains(field)
            : true;
      default:
        return true;
    }
  }

  /// Identity of the connected account, used to scope the caches above.
  Future<String?> _accountKey() async {
    final session = await OdooSessionManager.getCurrentSession();
    if (session == null) return null;
    return '${session.serverUrl}|${session.database}|${session.userId}';
  }

  /// The profile cache key for the connected account.
  Future<String?> _cacheKey() async {
    final account = await _accountKey();
    return account == null ? null : '$_cacheKeyUser|$account';
  }

  /// This model's `fields_get`, keyed by field name. Throws on any RPC
  /// failure — deliberately not swallowed here, so a dropped connection is
  /// what the caller's own `catch` sees rather than looking identical to
  /// "the model genuinely has none of these fields".
  ///
  /// `related` is requested alongside `type` so a caller can tell a plain
  /// stored column from a field that merely proxies another record's — the two
  /// behave very differently on write.
  Future<Map<String, Map<String, dynamic>>> _describeFields(
    String model,
  ) async {
    final result = await OdooSessionManager.callKwWithCompany({
      'model': model,
      'method': 'fields_get',
      'args': [
        <String>[],
        ['type', 'related'],
      ],
      'kwargs': const {},
    });
    if (result is! Map) return const {};
    return result.map(
      (key, value) => MapEntry(
        '$key',
        value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{},
      ),
    );
  }

  /// True when [describe] shows the field is `related` through `employee_id`
  /// — i.e. it writes onto the user's `hr.employee`, not onto `res.users`.
  ///
  /// Odoo reports `related` as a dotted path (`employee_id.mobile_phone`);
  /// some releases hand it back as a list of segments instead.
  bool _isEmployeeBacked(Map<String, dynamic>? describe) {
    final related = describe?['related'];
    if (related is String) return related.startsWith('employee_id.');
    if (related is List && related.isNotEmpty) {
      return '${related.first}' == 'employee_id';
    }
    return false;
  }

  /// Whether the signed-in user has an `hr.employee` behind them for the
  /// company the request runs under.
  ///
  /// `employee_id` is in `hr`'s `HR_READABLE_FIELDS`, so reading it alone takes
  /// the same-user sudo path and works for any user, not just HR staff. Odoo
  /// returns `false` for an unset many2one and `[id, name]` otherwise.
  Future<bool> _hasLinkedEmployee() async {
    final session = await OdooSessionManager.getCurrentSession();
    if (session == null) return false;
    final rows = await OdooSessionManager.callKwWithCompany({
      'model': 'res.users',
      'method': 'read',
      'args': [
        [session.userId],
        ['employee_id'],
      ],
      'kwargs': const {},
    });
    if (rows is! List || rows.isEmpty) return false;
    final value = (rows.first as Map)['employee_id'];
    return value is List && value.isNotEmpty;
  }

  /// Resolves which field holds the phone number and which model it lives on.
  ///
  /// `res.users` is probed *first*, unlike the mobile resolution below. `hr`
  /// puts `work_phone` there, related through `employee_id`, and that is the
  /// number Odoo's own user form shows as "Work Phone" — whereas
  /// `res.partner.phone` survives on every release, so probing the partner
  /// first would always win and the app would quietly display a different
  /// number from the one the user sees in Odoo.
  ///
  /// Falls back to `res.partner.phone`, which is what a database without `hr`
  /// — or a user with no employee behind them — actually has.
  Future<String?> _getPhoneFieldName() async {
    final accountKey = await _accountKey();
    if (_phoneFieldAccountKey != accountKey) {
      _phoneFieldAccountKey = accountKey;
      _phoneFieldResolved = false;
      _phoneFieldName = null;
      _phoneFieldModel = null;
    }
    if (_phoneFieldResolved) return _phoneFieldName;

    try {
      final userFields = await _describeFields('res.users');
      const userCandidates = ['work_phone', 'x_studio_work_phone'];
      for (final name in userCandidates) {
        final describe = userFields[name];
        if (describe == null) continue;
        // Same trap as the mobile field: employee-backed with no linked
        // employee means the related write targets an empty recordset and the
        // value is dropped silently.
        if (_isEmployeeBacked(describe) && !await _hasLinkedEmployee()) {
          continue;
        }
        _phoneFieldName = name;
        _phoneFieldModel = 'res.users';
        _phoneFieldResolved = true;
        return name;
      }

      final partnerFields = await _describeFields('res.partner');
      if (partnerFields.containsKey('phone')) {
        _phoneFieldName = 'phone';
        _phoneFieldModel = 'res.partner';
        _phoneFieldResolved = true;
        return 'phone';
      }

      _phoneFieldName = null;
      _phoneFieldModel = null;
      _phoneFieldResolved = true;
      return null;
    } catch (_) {
      // Not marked resolved, so a probe that failed on a dropped connection is
      // retried. `phone` on the partner is the safe stand-in meanwhile: it is
      // defined on every supported release.
      _phoneFieldName = null;
      _phoneFieldModel = null;
      return 'phone';
    }
  }

  /// Reads one resolved `res.users` field value on its own.
  ///
  /// Deliberately a separate, single-field read rather than part of the wide
  /// one: `res.users.read` only takes the same-user sudo path when *every*
  /// requested field is self-readable, and `hr` puts `mobile_phone` there.
  /// Asked for alone it comes back for any user; asked for alongside the rest
  /// of the profile it would lose that bypass and fall back to plain ACLs on
  /// `hr.employee`.
  Future<String?> _readUserFieldValue(String field) async {
    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null) return null;
      final rows = await OdooSessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'read',
        'args': [
          [session.userId],
          [field],
        ],
        'kwargs': const {},
      });
      if (rows is! List || rows.isEmpty) return null;
      final value = (rows.first as Map)[field];
      if (value == null || value == false) return null;
      final text = value.toString();
      return text.isEmpty || text == 'false' ? null : text;
    } catch (_) {
      return null;
    }
  }

  /// Which `res.users` fields to read, discovered with `fields_get` rather than
  /// hard-coded, so the profile carries what the connected release actually
  /// exposes without the app keeping a per-version list in sync. The
  /// `res.partner` schema is probed alongside it, for the row gating above.
  ///
  /// `fields_get` skips every field the caller may not read, which covers a
  /// field restricted by its own `groups`. Three kinds are dropped on the way
  /// out:
  ///
  ///  * every `binary` except `image_1920` — a user record carries
  ///    `image_1920/1024/512/256/128` plus a matching `avatar_*` for each, all
  ///    base64, which is megabytes for images this screen never shows;
  ///  * `one2many`/`many2many` — `groups_id` alone is hundreds of ids;
  ///  * anything `related` through `employee_id`. `fields_get` cannot vouch for
  ///    these: `hr` declares them on `res.users` with no `groups` of their own,
  ///    so they pass the filter and then raise on *read* when the underlying
  ///    `hr` field is restricted, failing the whole profile read. The mobile
  ///    field is never read from res.users at all — see
  ///    [_getPartnerMobileFieldName].
  ///
  /// Filtering on `store` would be wrong: Odoo defaults related fields to
  /// `store=False`, and on `res.users` that is every partner-delegated field,
  /// `name` and `email` included.
  Future<List<String>> _resolveProfileFields() async {
    final accountKey = await _accountKey();
    if (_profileFieldsAccountKey != accountKey) {
      _profileFieldsAccountKey = accountKey;
      _profileUserFieldsCache = null;
      _discoveredUserFields = {};
      _discoveredPartnerFields = {};
      _userFieldsDiscovered = false;
      _partnerFieldsDiscovered = false;
    }
    // Probed on its own so a transient failure here retries on the next fetch
    // instead of being short-circuited by the cached user-field list below.
    await _ensurePartnerFieldsDiscovered();

    final cached = _profileUserFieldsCache;
    if (cached != null) return cached;

    try {
      final described = await _describeFields('res.users');
      if (described.isEmpty) return _fallbackUserFields;

      const skippedTypes = {'one2many', 'many2many'};
      final fields = <String>[];
      described.forEach((name, describe) {
        final type = describe['type']?.toString() ?? '';
        if (skippedTypes.contains(type)) return;
        if (type == 'binary' && name != 'image_1920') return;
        if (_isEmployeeBacked(describe)) return;
        fields.add(name);
      });

      if (fields.isEmpty) return _fallbackUserFields;
      fields.sort();

      _profileUserFieldsCache = fields;
      _discoveredUserFields = fields.toSet();
      _userFieldsDiscovered = true;
      return fields;
    } catch (_) {
      // Not cached, so a probe that failed on a dropped connection is retried
      // rather than pinning the profile to the short list for the session.
      return _fallbackUserFields;
    }
  }

  /// Learns which `res.partner` fields this server defines, for the address
  /// and phone rows.
  ///
  /// A failure leaves [_partnerFieldsDiscovered] false, which reads as
  /// "unknown" rather than "absent" — the rows keep showing instead of all
  /// vanishing on one dropped call — and the probe runs again next fetch.
  Future<void> _ensurePartnerFieldsDiscovered() async {
    if (_partnerFieldsDiscovered) return;
    try {
      _discoveredPartnerFields = (await _describeFields(
        'res.partner',
      )).keys.toSet();
      _partnerFieldsDiscovered = _discoveredPartnerFields.isNotEmpty;
    } catch (_) {
      _discoveredPartnerFields = {};
    }
  }

  /// Sets [_versionSaysMobileExists] from the connected release, cheaply and
  /// without touching `res.partner`.
  ///
  /// Runs before [loadCachedUser] paints, which is exactly when it has to: the
  /// real probe arrives no earlier than the network fetch, and the cached
  /// profile paints well before that. In the gap, [hasMobileField] was null and
  /// the screen's `?? true` default showed the Mobile row on every server,
  /// Odoo 19 included, until the fetch caught up and hid it again.
  Future<void> _primeMobileFieldVersionGuess() async {
    final accountKey = await _accountKey();
    if (_mobileFieldAccountKey != accountKey) {
      _mobileFieldAccountKey = accountKey;
      _mobileFieldResolved = false;
      _partnerMobileFieldNameCache = null;
      _mobileFieldModel = null;
      _versionSaysMobileExists = null;
    }
    if (_versionSaysMobileExists != null || _mobileFieldResolved) return;
    try {
      final compat = await OdooCompat.current();
      _versionSaysMobileExists = compat.hasMobileField;
    } catch (_) {
      // Left null: an unresolved guess falls through to the screen's own
      // `?? true`, which is the behaviour this had before priming existed.
    }
  }

  /// Resolves which field holds the mobile number and which model it lives on,
  /// caching both.
  ///
  /// Odoo 19 removed `res.partner.mobile` and merged it into `phone`, so the
  /// standard name is only probed on releases that still define it. Custom
  /// names are checked after it, not before: on 16/17/18 the standard field is
  /// where Odoo's own contact form puts the number, and a stray Studio field
  /// must not shadow it.
  Future<String?> _getPartnerMobileFieldName() async {
    await _primeMobileFieldVersionGuess();
    final accountKey = await _accountKey();
    if (_mobileFieldAccountKey != accountKey) {
      _mobileFieldAccountKey = accountKey;
      _mobileFieldResolved = false;
      _partnerMobileFieldNameCache = null;
      _mobileFieldModel = null;
      _versionSaysMobileExists = null;
    }

    if (_mobileFieldResolved) return _partnerMobileFieldNameCache;

    final compat = await OdooCompat.current();
    _versionSaysMobileExists = compat.hasMobileField;

    try {
      // `fields_get`, not a search on `ir.model.fields`: that model grants
      // `base.group_user` no access at all on 16 through 19 — only
      // `group_erp_manager` can read it — so probing it raised an AccessError
      // for every non-admin, which is why the Mobile row behaved differently
      // for admin than for an ordinary user on the same database.
      final partnerFields = await _describeFields('res.partner');
      final candidates = <String>[
        if (compat.hasMobileField) 'mobile',
        'mobile_phone',
        'x_studio_mobile_phone',
      ];
      for (final name in candidates) {
        if (partnerFields.containsKey(name)) {
          _partnerMobileFieldNameCache = name;
          _mobileFieldModel = 'res.partner';
          _mobileFieldResolved = true;
          return name;
        }
      }

      // Odoo's own `hr` module puts `mobile_phone` on `res.users` — related to
      // `hr.employee.mobile_phone` — not on `res.partner`, and Odoo's own
      // Preferences form writes it there. On Odoo 19, where
      // `res.partner.mobile` was removed, that is the only place a mobile
      // number lives, so without this probe the row vanishes on a server that
      // plainly has one. `mobile` itself is excluded: no supported release
      // defines it on res.users.
      final userFields = await _describeFields('res.users');
      const userCandidates = ['mobile_phone', 'x_studio_mobile_phone'];
      for (final name in userCandidates) {
        final describe = userFields[name];
        if (describe == null) continue;
        // Existing is not enough when it is `hr`'s, which is related through
        // `employee_id` — a computed m2o resolved as "the hr.employee whose
        // user_id is me AND whose company_id is env.company". With no such
        // employee it is an empty recordset and the related-field write
        // targets nothing: the value is dropped with no error, which is
        // exactly "I edit Mobile and nothing happens". Offering the row in
        // that state offers an edit the server will silently discard.
        //
        // `continue`, not `break`: a rejected `mobile_phone` must not stop a
        // plain stored `x_studio_mobile_phone` from being found.
        if (_isEmployeeBacked(describe) && !await _hasLinkedEmployee()) {
          continue;
        }
        _partnerMobileFieldNameCache = name;
        _mobileFieldModel = 'res.users';
        _mobileFieldResolved = true;
        return name;
      }

      _partnerMobileFieldNameCache = null;
      _mobileFieldModel = null;
      _mobileFieldResolved = true;
      return null;
    } catch (_) {
      // Not marked resolved — a probe that failed on a dropped connection must
      // be retried. Until it succeeds the release's own answer stands, so
      // 16/17/18 still write `mobile` and 19 still leaves it out.
      _partnerMobileFieldNameCache = null;
      _mobileFieldModel = null;
      return compat.hasMobileField ? 'mobile' : null;
    }
  }

  Map<String, dynamic> _normalizePartnerUpdates(Map<String, dynamic> updates) {
    final out = <String, dynamic>{};
    updates.forEach((key, value) {
      String k = key;
      if (k == 'mobile_phone') k = 'mobile';
      out[k] = value;
    });
    return out;
  }

  /// Renames the canonical `mobile` key to whatever `res.partner` field this
  /// server actually has, or drops it when there is none.
  Future<Map<String, dynamic>> _preparePartnerUpdatesForServer(
    Map<String, dynamic> normalized,
  ) async {
    if (!normalized.containsKey('mobile')) return normalized;
    final fieldName = await _getPartnerMobileFieldName();
    // Usable here only when it actually lives on res.partner. It can just as
    // well be `hr`'s res.users.mobile_phone — renaming to that and sending it
    // to res.partner makes Odoo reject the whole write for an unrecognized
    // field, taking phone/website/function down with it. Dropping the key
    // loses one value; keeping it loses all. (saveProfileEdits already routes
    // the res.users case away from here, but updatePartnerFields is public.)
    if (fieldName == null || _mobileFieldModel != 'res.partner') {
      final copy = Map<String, dynamic>.from(normalized);
      copy.remove('mobile');
      return copy;
    }
    if (fieldName == 'mobile') return normalized;
    final copy = Map<String, dynamic>.from(normalized);
    final value = copy.remove('mobile');
    copy[fieldName] = value;
    return copy;
  }

  Future<void> initialize() async {
    _startConnectivityListener();
    await loadCachedUser();
    await fetchUserProfile();
    await loadCountries();
  }

  void _startConnectivityListener() {
    // Subscribed once: this runs every time the Profile screen opens, and a
    // new subscription per visit would pile up for the life of the app.
    _connectivitySub ??= Connectivity().onConnectivityChanged.listen((
      results,
    ) async {
      final hasNet = await _checkInternet();
      _hasInternet = hasNet;
      notifyListeners();
    });

    _checkInternet().then((hasNet) {
      _hasInternet = hasNet;
      notifyListeners();
    });
  }

  Future<bool> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('one.one.one.one');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> loadCachedUser() async {
    // Ahead of the paint below, not after it — see
    // [_primeMobileFieldVersionGuess] for why the ordering is the point.
    await _primeMobileFieldVersionGuess();
    try {
      final key = await _cacheKey();
      if (key == null) return;
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(key);
      if (cached != null && cached.isNotEmpty) {
        final data = jsonDecode(cached) as Map<String, dynamic>;
        _userData = data;
        final img = OdooBinary.base64(data['image_1920']);
        if (img != null) {
          try {
            _userAvatar = await compute(decodeBase64ToBytes, img);
          } catch (_) {}
        }
        _isLoading = false;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// [forceRefresh] is accepted for existing callers; every call reads the
  /// server.
  Future<void> fetchUserProfile({bool forceRefresh = false}) async {
    if (_userData == null) {
      _isLoading = true;
    }
    _error = null;
    notifyListeners();

    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      Future<dynamic> readUser(List<String> fields) =>
          OdooSessionManager.callKwWithCompany({
            'model': 'res.users',
            'method': 'read',
            'args': [
              [session.userId],
              fields,
            ],
            'kwargs': {},
          });

      final wanted = await _resolveProfileFields();
      dynamic res;
      try {
        res = await readUser(wanted);
      } catch (_) {
        // A single misbehaving field must not cost the whole profile. Some
        // modules add non-stored computed fields to res.users whose compute
        // needs rights an ordinary user does not have, and `fields_get` cannot
        // see that coming — so the wide read is retried once as the short list
        // that is known to work on every release.
        _profileUserFieldsCache = null;
        res = await readUser(_fallbackUserFields);
      }

      if (res is List && res.isNotEmpty) {
        final data = res.first as Map<String, dynamic>;
        // Base64 text through Odoo 19, a {content, size} object on 20. Reduced
        // to the text here, once, so the cached profile, the app bar and the
        // profile screen all read the same thing on every release.
        data['image_1920'] = OdooBinary.base64(data['image_1920']) ?? false;

        final partner = data['partner_id'];
        if (partner != null && partner is List && partner.isNotEmpty) {
          try {
            final mobileFieldName = await _getPartnerMobileFieldName();
            // `hr`'s res.users.mobile_phone is the common case here on 19.
            final mobileOnUsers = _mobileFieldModel == 'res.users';
            final phoneFieldName = await _getPhoneFieldName();
            final phoneOnUsers = _phoneFieldModel == 'res.users';

            // Only the fields this server defines: Odoo rejects the entire
            // read for one unrecognized name, which would take the address
            // and phone down with it.
            final fields = _partnerFieldsDiscovered
                ? _wantedPartnerFields
                      .where(_discoveredPartnerFields.contains)
                      .toList()
                : List<String>.from(_wantedPartnerFields);
            // Added only when they really live on res.partner: asking this
            // read for a res.users-only name would fail the whole call.
            if (mobileFieldName != null && !mobileOnUsers) {
              fields.add(mobileFieldName);
            }
            if (phoneFieldName != null && !phoneOnUsers) {
              fields.add(phoneFieldName);
            }

            if (fields.isNotEmpty) {
              final partnerRes = await OdooSessionManager.callKwWithCompany({
                'model': 'res.partner',
                'method': 'read',
                'args': [
                  [partner[0]],
                  fields,
                ],
                'kwargs': {},
              });

              if (partnerRes is List && partnerRes.isNotEmpty) {
                final partnerData = partnerRes.first as Map<String, dynamic>;
                for (final field in fields) {
                  data[field] = partnerData[field];
                }

                String? mobileValue;
                if (mobileFieldName != null) {
                  if (mobileOnUsers) {
                    // Its own read — see [_readUserFieldValue] for why that
                    // is what makes it readable for a non-HR user.
                    mobileValue = await _readUserFieldValue(mobileFieldName);
                  } else {
                    // Odoo sends an empty value as the bool `false`, so the
                    // comparison has to be on the rendered text — comparing
                    // the raw value to 'false' never matches a bool and
                    // stored the literal string "false".
                    final text = partnerData[mobileFieldName]?.toString() ?? '';
                    if (text.isNotEmpty && text != 'false') {
                      mobileValue = text;
                    }
                  }
                }
                data['mobile'] = mobileValue ?? '';

                String? phoneValue;
                if (phoneFieldName != null) {
                  if (phoneOnUsers) {
                    phoneValue = await _readUserFieldValue(phoneFieldName);
                  } else {
                    final text = partnerData[phoneFieldName]?.toString() ?? '';
                    if (text.isNotEmpty && text != 'false') {
                      phoneValue = text;
                    }
                  }
                }
                data['phone'] = phoneValue ?? '';
              }
            }
          } catch (_) {}
        }

        _userData = data;
        final img = data['image_1920'];
        if (img != null && img is String && img.isNotEmpty && img != 'false') {
          try {
            _userAvatar = base64Decode(img);
          } catch (_) {}
        } else {
          // A removed photo must not keep showing the old one here or in the
          // app bar, which both read this.
          _userAvatar = null;
        }

        final key = await _cacheKey();
        if (key != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(key, jsonEncode(data));
        }

        // Keeps the Switch Account list's cached name/avatar for this
        // account in step with the profile, which otherwise only picks up
        // an edit on the next full login — every fetch here re-syncs it
        // (not just a save), so opening the profile screen after editing
        // elsewhere also catches it up.
        final nameValue = data['name'];
        await SessionService.instance.updateCurrentAccountDisplay(
          name:
              (nameValue is String &&
                  nameValue.isNotEmpty &&
                  nameValue != 'false')
              ? nameValue
              : null,
          imageBase64: (img is String && img.isNotEmpty && img != 'false')
              ? img
              : null,
        );
      }
    } catch (e) {
      _error = 'Failed to fetch user profile: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Applies profile edits, routing every field to the model that owns it on
  /// the connected server.
  ///
  /// `res.users.write` bypasses access rights only when *every* key is
  /// self-writeable, so the split is per-release rather than fixed: Odoo 19
  /// takes `phone` there too, 16/17/18 must send it to `res.partner`.
  ///
  /// `mobile` cannot be classified from that release-based set at all — which
  /// model owns it depends on this server's schema — so it is routed
  /// separately, using the resolved field name whenever that lives on
  /// `res.users`.
  ///
  /// Throws if the server rejects either write, so the caller can tell the user
  /// the change did not stick.
  Future<void> saveProfileEdits(Map<String, dynamic> changes) async {
    if (changes.isEmpty) return;

    final compat = await OdooCompat.current();
    final selfWritable = compat.userSelfWritableFields;

    final userUpdates = <String, dynamic>{};
    final partnerUpdates = <String, dynamic>{};

    final remaining = Map<String, dynamic>.from(changes);
    if (remaining.containsKey('mobile')) {
      // Never classified by the release-based set: which model owns it depends
      // on this server's schema — a plain res.partner.mobile, `hr`'s
      // res.users.mobile_phone, a Studio field, or nothing at all.
      final value = remaining.remove('mobile');
      await _getPartnerMobileFieldName();
      final resolvedField = _partnerMobileFieldNameCache;
      if (_mobileFieldModel == 'res.users' && resolvedField != null) {
        userUpdates[resolvedField] = value;
      } else {
        // res.partner, or unresolved: `_preparePartnerUpdatesForServer`
        // renames or drops it per this server's schema.
        partnerUpdates['mobile'] = value;
      }
    }

    // Same treatment as mobile, and for the same reason: `hr`'s
    // res.users.work_phone and res.partner.phone are different fields holding
    // different numbers, so the release-based set cannot decide this either.
    if (remaining.containsKey('phone')) {
      final value = remaining.remove('phone');
      final resolvedPhone = await _getPhoneFieldName();
      if (_phoneFieldModel == 'res.users' && resolvedPhone != null) {
        userUpdates[resolvedPhone] = value;
      } else if (resolvedPhone != null) {
        partnerUpdates[resolvedPhone] = value;
      }
    }

    remaining.forEach((field, value) {
      if (selfWritable.contains(field)) {
        userUpdates[field] = value;
      } else {
        partnerUpdates[field] = value;
      }
    });

    try {
      if (userUpdates.isNotEmpty) {
        await _writeUserFields(userUpdates);
      }
      if (partnerUpdates.isNotEmpty) {
        await _writePartnerFields(partnerUpdates);
      }
    } finally {
      // One refetch for the whole save rather than one per model — a refetch
      // between the two writes would paint a half-applied profile. In a
      // `finally` because a save can be *partly* applied: the res.users write
      // commits before a failing res.partner write, and without this the
      // screen would keep showing the old name, re-send it on every retry,
      // and never agree with the server.
      await fetchUserProfile();
    }
  }

  Future<void> _writeUserFields(Map<String, dynamic> updates) async {
    final session = await OdooSessionManager.getCurrentSession();
    if (session == null) {
      throw Exception('No active session');
    }
    await OdooSessionManager.callKwWithCompany({
      'model': 'res.users',
      'method': 'write',
      'args': [
        [session.userId],
        updates,
      ],
      'kwargs': {},
    });
  }

  Future<void> _writePartnerFields(Map<String, dynamic> updates) async {
    final partnerId = _userData?['partner_id'];
    if (partnerId == null || partnerId is! List || partnerId.isEmpty) {
      throw Exception('Partner ID not found');
    }
    final toSend = await _preparePartnerUpdatesForServer(
      _normalizePartnerUpdates(updates),
    );
    if (toSend.isEmpty) return;
    await OdooSessionManager.callKwWithCompany({
      'model': 'res.partner',
      'method': 'write',
      'args': [
        [partnerId[0]],
        toSend,
      ],
      'kwargs': {},
    });
  }

  Future<void> updateProfileFields(Map<String, dynamic> updates) async {
    await _writeUserFields(updates);
    await fetchUserProfile();
  }

  Future<void> updatePartnerFields(Map<String, dynamic> updates) async {
    await _writePartnerFields(updates);
    await fetchUserProfile();
  }

  Future<void> updateProfileImage(String base64Image) async {
    await _writeUserFields({'image_1920': base64Image});
    await fetchUserProfile();
  }

  /// Writes the address as one payload. Only the fields this server defines are
  /// sent, so a release that dropped one of them does not fail the whole write.
  Future<void> updateAddressFields(Map<String, dynamic> addressData) async {
    final partnerId = _userData?['partner_id'];
    if (partnerId == null || partnerId is! List || partnerId.isEmpty) {
      throw Exception('Partner ID not found');
    }

    final toSend = <String, dynamic>{};
    addressData.forEach((field, value) {
      if (isProfileFieldAvailable(field)) toSend[field] = value;
    });
    if (toSend.isEmpty) return;

    await OdooSessionManager.callKwWithCompany({
      'model': 'res.partner',
      'method': 'write',
      'args': [
        [partnerId[0]],
        toSend,
      ],
      'kwargs': {},
    });

    await fetchUserProfile();
  }

  Future<Map<String, dynamic>?> loadRelatedCompany() async {
    try {
      final partnerId = _userData?['partner_id'];
      if (partnerId == null || partnerId is! List || partnerId.isEmpty) {
        return null;
      }

      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'res.partner',
        'method': 'read',
        'args': [
          [partnerId[0]],
        ],
        'kwargs': {
          'fields': ['parent_id'],
        },
      });

      if (res is List && res.isNotEmpty) {
        final row = res.first as Map<String, dynamic>;
        if (row['parent_id'] is List &&
            (row['parent_id'] as List).length >= 2 &&
            row['parent_id'][0] != null) {
          return {
            'id': row['parent_id'][0],
            'name': row['parent_id'][1]?.toString(),
          };
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateRelatedCompany(int? companyId) async {
    try {
      final partnerId = _userData?['partner_id'];
      if (partnerId == null || partnerId is! List || partnerId.isEmpty) {
        throw Exception('Partner ID not found');
      }

      await OdooSessionManager.callKwWithCompany({
        'model': 'res.partner',
        'method': 'write',
        'args': [
          [partnerId[0]],
          {'parent_id': companyId ?? false},
        ],
        'kwargs': {},
      });

      await fetchUserProfile();
    } catch (e) {
      _error = 'Failed to update related company: $e';
      rethrow;
    }
  }

  Future<void> loadCountries() async {
    _isLoadingCountries = true;
    notifyListeners();

    try {
      _countries = await fetchCountries();
    } catch (_) {} finally {
      _isLoadingCountries = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> fetchCountries() async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'res.country',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'fields': ['id', 'name', 'code'],
          'order': 'name ASC',
        },
      });
      return result is List ? result.cast<Map<String, dynamic>>() : [];
    } catch (_) {
      rethrow;
    }
  }

  Future<void> loadStates(int countryId) async {
    _isLoadingStates = true;
    notifyListeners();

    try {
      _states = await fetchStates(countryId);
    } catch (_) {} finally {
      _isLoadingStates = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> fetchStates(int countryId) async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'res.country.state',
        'method': 'search_read',
        'args': [
          [
            ['country_id', '=', countryId],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'name', 'code'],
          'order': 'name ASC',
        },
      });
      return result is List ? result.cast<Map<String, dynamic>>() : [];
    } catch (_) {
      rethrow;
    }
  }

  String formatAddress(Map<String, dynamic> data) {
    final parts = [
      if (data['street'] != null &&
          data['street'].toString().isNotEmpty &&
          data['street'].toString().toLowerCase() != 'false')
        data['street'],
      if (data['street2'] != null &&
          data['street2'].toString().isNotEmpty &&
          data['street2'].toString().toLowerCase() != 'false')
        data['street2'],
      if (data['city'] != null &&
          data['city'].toString().isNotEmpty &&
          data['city'].toString().toLowerCase() != 'false')
        data['city'],
      if (data['state_id'] is List &&
          data['state_id'].length > 1 &&
          data['state_id'][1] != null &&
          data['state_id'][1].toString().isNotEmpty &&
          data['state_id'][1].toString().toLowerCase() != 'false')
        data['state_id'][1],
      if (data['zip'] != null &&
          data['zip'].toString().isNotEmpty &&
          data['zip'].toString().toLowerCase() != 'false')
        data['zip'],
      if (data['country_id'] is List &&
          data['country_id'].length > 1 &&
          data['country_id'][1] != null &&
          data['country_id'][1].toString().isNotEmpty &&
          data['country_id'][1].toString().toLowerCase() != 'false')
        data['country_id'][1],
    ];
    return parts.isNotEmpty ? parts.join(', ') : 'No address set';
  }

  void clearStates() {
    _states = [];
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      _error = 'Logout failed: $e';
      rethrow;
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  void resetState() {
    _isLoading = true;
    _userData = null;
    _userAvatar = null;
    _error = null;
    _hasInternet = true;
    _countries = [];
    _states = [];
    _isLoadingCountries = false;
    _isLoadingStates = false;

    // This provider outlives the account, so every schema answer resolved
    // against the old server has to go with it.
    _profileUserFieldsCache = null;
    _profileFieldsAccountKey = null;
    _discoveredUserFields = {};
    _discoveredPartnerFields = {};
    _userFieldsDiscovered = false;
    _partnerFieldsDiscovered = false;
    _partnerMobileFieldNameCache = null;
    _mobileFieldModel = null;
    _mobileFieldAccountKey = null;
    _mobileFieldResolved = false;
    _versionSaysMobileExists = null;
    _phoneFieldName = null;
    _phoneFieldModel = null;
    _phoneFieldAccountKey = null;
    _phoneFieldResolved = false;
    OdooVersion.reset();

    notifyListeners();
  }
}
