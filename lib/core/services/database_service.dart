import 'dart:convert';
import 'dart:io';

/// Thrown when the server responds successfully but database listing is
/// disabled (Odoo returns a JSON-RPC error, or a null result, for
/// `/web/database/list`) — a common production setting on Odoo Online and
/// odoo.sh.
class DatabaseListingDisabledException implements Exception {
  final String message;
  const DatabaseListingDisabledException(this.message);

  @override
  String toString() => message;
}

/// Service for fetching database lists directly from Odoo servers via RPC.
class DatabaseService {
  /// Fetches the list of available databases for a given [url].
  ///
  /// Transport failures are rethrown *unchanged* — [SocketException],
  /// [HandshakeException], [TimeoutException], [FormatException] and friends
  /// all carry the detail [LoginProvider.fetchDatabaseList] turns into a
  /// specific, actionable message. Wrapping them in a plain `Exception`
  /// collapses every network problem into one generic string and makes the
  /// caller's typed `on ...` handlers unreachable.
  Future<List<String>> fetchDatabaseList(String url) async {
    String normalizedUrl = url.trim();
    if (!normalizedUrl.startsWith('http://') &&
        !normalizedUrl.startsWith('https://')) {
      normalizedUrl = 'https://$normalizedUrl';
    }
    if (normalizedUrl.endsWith('/')) {
      normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
    }

    final HttpClient httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12)
      ..idleTimeout = const Duration(seconds: 10)
      ..maxConnectionsPerHost = 5
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;

    final String responseBody;
    try {
      final request = await httpClient.postUrl(
        Uri.parse('$normalizedUrl/web/database/list'),
      );

      request.headers.set('Content-Type', 'application/json');
      request.write(
        jsonEncode({'jsonrpc': '2.0', 'method': 'call', 'params': {}, 'id': 1}),
      );

      final response = await request.close();
      responseBody = await response.transform(utf8.decoder).join();
    } finally {
      httpClient.close(force: true);
    }

    final jsonResponse = jsonDecode(responseBody);

    // Odoo answers with a JSON-RPC error object — no "result" key at all —
    // when database listing is turned off server-side. Reported as its own
    // exception so the caller can say so, rather than reading the missing
    // list as "this server has no databases".
    if (jsonResponse is Map && jsonResponse['error'] != null) {
      final serverError =
          jsonResponse['error']?['data']?['message'] ??
          jsonResponse['error']?['message'] ??
          jsonResponse['error'].toString();
      throw DatabaseListingDisabledException(
        'The listing database is currently disabled. $serverError',
      );
    }

    final result = jsonResponse is Map ? jsonResponse['result'] : null;
    if (result == null) {
      throw const DatabaseListingDisabledException(
        'The listing database is currently disabled.',
      );
    }

    if (result is! List) {
      throw const FormatException(
        'Server returned an unexpected database list format.',
      );
    }

    return result.map((db) => db.toString()).toList();
  }
}
