import 'dart:convert';
import 'dart:typed_data';

/// Reads a binary field (`image_1920`, `image_1024`, `badge_image`, …) as
/// Odoo hands it back from `read` / `search_read` / `onchange`.
///
/// The shape depends on the release:
///
/// * Odoo 17 – 19 send the base64 text itself, or `false` when the field is
///   empty.
/// * Odoo 20 sends an object instead — `{'content': <base64>, 'size': 1234}`,
///   plus `'filename'` when the file has a name — or `false` when empty
///   (`Binary.convert_to_read`). There is no context flag that turns that off.
///
/// Code that tests `value is String` sees the Odoo 20 object as "no image",
/// which is how every photo went missing there. Read binaries through this
/// instead; it accepts both, so no version check is needed.
class OdooBinary {
  const OdooBinary._();

  /// The base64 text in [value], or null when it holds no content: `false`,
  /// `null`, an empty string, or an object without a `content` entry (what a
  /// server sends when it reports only the file's size).
  static String? base64(dynamic value) {
    if (value is String) {
      final text = value.trim();
      return text.isEmpty || text == 'false' ? null : text;
    }
    if (value is Map) return base64(value['content']);
    return null;
  }

  /// The decoded bytes in [value], or null when it holds no content or the
  /// content is not valid base64.
  static Uint8List? bytes(dynamic value) {
    final text = base64(value);
    if (text == null) return null;
    try {
      return base64Decode(text);
    } catch (_) {
      return null;
    }
  }
}
