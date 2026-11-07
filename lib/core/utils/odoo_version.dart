import '../models/appsession.dart';
import '../services/odoo_session_manager.dart';

/// Normalises the many shapes Odoo reports its version in, so the rest of the
/// app can compare versions without guessing which one it was handed.
///
/// The same server is described differently depending on where the value came
/// from:
///
/// * `odoo_rpc`'s `OdooSession.fromSessionInfo` uses `server_version_info[0]`
///   and yields the bare major — `"19"`.
/// * `/web/session/get_session_info` reports `server_version` — `"19.0"`,
///   `"18.0+e"`, or `"saas~18.4"` on Odoo Online.
///
/// Storing whichever one happened to arrive is what made checks like
/// `version == '19'` pass right after a password login and fail after the
/// session was refreshed, and `version.startsWith('18')` miss `saas~18.4`
/// entirely. Everything is reduced to the major number instead: that is the
/// only part any of this app's version branches actually care about.
class OdooVersion {
  const OdooVersion._();

  /// First run of digits in [raw], which is the major for every form Odoo
  /// uses: `19`, `"19"`, `"19.0"`, `"18.0+e"`, `"saas~18.4"`, and the
  /// `server_version_info` list `[19, 0, 0, 'final', 0, '']`.
  static int? majorOf(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw > 0 ? raw : null;
    if (raw is List) return raw.isEmpty ? null : majorOf(raw.first);

    final text = raw.toString().trim();
    // `null` gets here from records written before versions were normalised:
    // `version.toString()` on a null used to be persisted verbatim.
    if (text.isEmpty || text == 'null' || text == 'false') return null;

    final match = RegExp(r'\d+').firstMatch(text);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }

  /// The canonical form this app stores and compares: the major as a string,
  /// or an empty string when [raw] carries no usable version.
  static String normalize(dynamic raw) => majorOf(raw)?.toString() ?? '';

  /// True when [raw] names Odoo [major] or newer. Unknown versions answer
  /// false, so a missing version never silently opts a session into behaviour
  /// its server may not support.
  static bool isAtLeast(dynamic raw, int major) {
    final parsed = majorOf(raw);
    return parsed != null && parsed >= major;
  }

  /// True when [raw] names Odoo older than [major]. Unknown versions answer
  /// false here too — neither branch of a comparison should be taken on a
  /// guess.
  static bool isBelow(dynamic raw, int major) {
    final parsed = majorOf(raw);
    return parsed != null && parsed < major;
  }

  /// True when [raw] names exactly Odoo [major].
  static bool isExactly(dynamic raw, int major) => majorOf(raw) == major;

  /// Oldest release this app was built against, and the newest one it has been
  /// checked against (Odoo 20).
  ///
  /// [maxSupported] is a statement about what was verified, not a ceiling: no
  /// call is refused above it. Every version gate in the app is a `>=` on the
  /// release that introduced the behaviour (see `OdooCompat`), so a newer
  /// server — 21 through 29 and beyond — takes the newest branch we know.
  /// Exact comparisons (`== 19`) are what would break that, so don't add them.
  static const int minSupported = 16;
  static const int maxSupported = 20;

  /// Used when no session records a version and the server cannot be asked,
  /// which in practice means "called before any login completed".
  static const int fallbackMajor = 18;

  /// Answers already obtained from the server, keyed by account identity so a
  /// switch to a different server re-resolves instead of reusing the old one.
  static final Map<String, int> _resolved = {};

  /// Single-flight discovery, scoped to one account so concurrent callers
  /// share a probe but a different account still gets its own.
  static String? _discoveryKey;
  static Future<int>? _discovery;

  static String _identityOf(AppSessionData s) =>
      '${s.serverUrl}|${s.database}|${s.userId}';

  /// Major version of the currently connected server, e.g. `16`.
  ///
  /// Reads the version the session already carries. Sessions stored without
  /// one fall through to asking the server, at most once per account.
  static Future<int> major() async {
    AppSessionData? session;
    try {
      session = await OdooSessionManager.getCurrentSession();
    } catch (_) {
      return fallbackMajor;
    }
    if (session == null) return fallbackMajor;

    final recorded = session.odooMajorVersion;
    if (recorded != null) return recorded;

    final cached = _resolved[_identityOf(session)];
    if (cached != null) return cached;

    return _discover(session);
  }

  static Future<int> _discover(AppSessionData session) {
    final key = _identityOf(session);
    final inFlight = _discovery;
    if (inFlight != null && _discoveryKey == key) return inFlight;

    final future = _queryServerVersion(session);
    _discoveryKey = key;
    _discovery = future;
    // Cleared once it settles, so this only ever deduplicates *concurrent*
    // callers. A probe that failed writes nothing to [_resolved], and holding
    // its completed future here would hand every later caller the fallback for
    // the rest of the session — on a 19 server that silently routes `phone` to
    // res.partner forever.
    future.whenComplete(() {
      if (identical(_discovery, future)) {
        _discovery = null;
        _discoveryKey = null;
      }
    });
    return future;
  }

  static Future<int> _queryServerVersion(AppSessionData session) async {
    // First choice: the session info. It is the same payload `odoo_rpc` reads
    // the version from at login, it is served to any signed-in user on every
    // release from 16 to 20, and it needs no model access rights.
    try {
      final info = await OdooSessionManager.safeCallRPC(
        '/web/session/get_session_info',
        'call',
        {},
      );
      if (info is Map) {
        final parsed =
            majorOf(info['server_version_info']) ??
            majorOf(info['server_version']);
        if (parsed != null) {
          _resolved[_identityOf(session)] = parsed;
          return parsed;
        }
      }
    } catch (_) {
      // fall through to the module lookup
    }

    try {
      // Without company context: the version is a property of the database,
      // not of whichever company happens to be selected. `ir.module.module` is
      // only readable by `base.group_system` on 19 and 20 (an ordinary employee
      // is refused), so this is a fallback for when the session info is
      // unavailable, not the primary route.
      final result = await OdooSessionManager.safeCallKwWithoutCompany({
        'model': 'ir.module.module',
        'method': 'search_read',
        'args': [
          [
            ['name', '=', 'base'],
          ],
          ['latest_version'],
        ],
        'kwargs': {'limit': 1},
      });

      if (result is List && result.isNotEmpty) {
        // `base` reports e.g. '16.0.1.3', so the leading number is the release.
        final parsed = majorOf((result.first as Map)['latest_version']);
        if (parsed != null) {
          _resolved[_identityOf(session)] = parsed;
          return parsed;
        }
      }
    } catch (_) {
      // fall through to the documented default
    }
    return fallbackMajor;
  }

  /// Drops every resolved version. Call on logout or account switch — a
  /// cached major would otherwise hand the new server the old one's field
  /// names.
  static void reset() {
    _resolved.clear();
    _discoveryKey = null;
    _discovery = null;
  }
}
