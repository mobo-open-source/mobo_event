import 'dart:convert';
import 'dart:typed_data';

/// Top-level so it can run in a background isolate through `compute`.
Uint8List decodeBase64ToBytes(String data) {
  return base64Decode(data);
}
