/// Format checks for the contact details a user can edit on their profile.
///
/// Each returns the message to show under the field, or null when the value
/// is acceptable. Both fields are optional in Odoo, so an empty value always
/// passes. Odoo itself stores these as free text and validates neither, so
/// these rules only have to keep obvious typos and wrong-field entries (an
/// email in the website box, letters in a phone) from being saved.
class ContactValidators {
  const ContactValidators._();

  /// E.164 caps a full international number at 15 digits; 7 is the shortest
  /// number that is usable on its own (local numbers in small countries).
  static const int _minPhoneDigits = 7;
  static const int _maxPhoneDigits = 15;

  static final RegExp _phoneCharacters = RegExp(r'^[0-9+\-().\s/]+$');

  /// A trailing extension: "ext 12", "ext. 12" or "x12".
  static final RegExp _phoneExtension = RegExp(
    r'\s*(?:ext\.?|x)\s*(\d{1,6})\s*$',
    caseSensitive: false,
  );

  /// Phone or mobile number, as typed by a person: digits with optional
  /// spaces, `-`, `.`, `/` and brackets, an optional leading `+` for the
  /// country code, and an optional extension.
  ///
  /// [label] names the field in the message ("Phone", "Mobile").
  static String? phone(String? value, {String label = 'Phone'}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;

    final number = text.replaceFirst(_phoneExtension, '');

    if (!_phoneCharacters.hasMatch(number)) {
      return '$label can only contain digits, spaces and + - ( ) . /';
    }
    if (number.indexOf('+', 1) != -1) {
      return 'Use + only at the start of the number';
    }
    if (!_bracketsBalanced(number)) {
      return 'Check the brackets in the $label number';
    }

    var digits = number.replaceAll(RegExp(r'\D'), '');
    // "00" is the international dialling prefix (0091… for +91…), not part of
    // the number, so it must not count towards the length.
    if (!number.startsWith('+') && digits.startsWith('00')) {
      digits = digits.substring(2);
    }

    if (digits.length < _minPhoneDigits) {
      return '$label number is too short (minimum $_minPhoneDigits digits)';
    }
    if (digits.length > _maxPhoneDigits) {
      return '$label number is too long (maximum $_maxPhoneDigits digits)';
    }
    return null;
  }

  static bool _bracketsBalanced(String text) {
    var open = 0;
    for (final unit in text.codeUnits) {
      if (unit == 0x28) {
        open++;
      } else if (unit == 0x29) {
        open--;
        if (open < 0) return false;
      }
    }
    return open == 0;
  }

  /// "scheme://" at the very start. Not just any "name:" — "example.com:8080"
  /// is a bare address with a port, not a scheme.
  static final RegExp _scheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://');
  static final RegExp _httpScheme = RegExp(r'^https?://', caseSensitive: false);
  static final RegExp _ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');

  /// One DNS label: letters or digits (Unicode, so internationalised names
  /// like "bücher" pass), hyphens only inside, at most 63 characters.
  static final RegExp _hostLabel = RegExp(
    r'^[\p{L}\p{N}](?:[\p{L}\p{N}-]{0,61}[\p{L}\p{N}])?$',
    unicode: true,
  );

  /// The last label: letters (2+), or punycode for an internationalised TLD.
  static final RegExp _topLevelDomain = RegExp(
    r'^(?:\p{L}{2,63}|xn--[a-z0-9-]{1,59})$',
    unicode: true,
    caseSensitive: false,
  );

  /// Website address. The scheme is optional — Odoo adds `http://` to a bare
  /// address itself — but when given it must be http or https. The host has
  /// to be a real domain name (with a top-level domain) or an IPv4 address.
  static String? website(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;

    if (RegExp(r'\s').hasMatch(text)) {
      return 'Website cannot contain spaces';
    }

    final hasScheme = _scheme.hasMatch(text);
    if (hasScheme && !_httpScheme.hasMatch(text)) {
      return 'Website must start with http:// or https://';
    }

    final uri = Uri.tryParse(hasScheme ? text : 'https://$text');
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      return _invalidWebsite;
    }
    if (uri.userInfo.isNotEmpty) {
      // "name@example.com" parses as user "name" at host "example.com", so
      // this is what a mistyped email address looks like here.
      return 'Enter a website address, not an email address';
    }

    // Uri percent-encodes a non-ASCII host; decode it to check the real name.
    final String host;
    try {
      host = Uri.decodeComponent(uri.host);
    } on FormatException {
      return _invalidWebsite;
    }
    // The host first: "tel:1234567" reads as host "tel", port 1234567, and
    // "not a website" is the more useful message than "bad port".
    if (!_validHost(host)) return _invalidWebsite;

    if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) {
      return 'The port must be between 1 and 65535';
    }
    return null;
  }

  static const String _invalidWebsite =
      'Enter a valid website, e.g. www.example.com';

  static bool _validHost(String host) {
    if (_ipv4.hasMatch(host)) {
      return host.split('.').every((part) => int.parse(part) <= 255);
    }
    if (host.length > 253) return false;

    final labels = host.split('.');
    if (labels.length < 2) return false;
    if (!labels.every(_hostLabel.hasMatch)) return false;
    return _topLevelDomain.hasMatch(labels.last);
  }
}
