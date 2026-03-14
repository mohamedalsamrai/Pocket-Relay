import 'dart:typed_data';

String shellEscape(String value) {
  return "'${value.replaceAll("'", "'\"'\"'")}'";
}

String formatFingerprint(Uint8List fingerprint) {
  return fingerprint
      .map((part) => part.toRadixString(16).padLeft(2, '0'))
      .join(':');
}

String normalizeFingerprint(String fingerprint) {
  return fingerprint.toLowerCase().replaceAll(RegExp(r'[^0-9a-f]'), '');
}
