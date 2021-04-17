import 'dart:convert' show base64, utf8;

String encodeBase64Str(String str) {
  return base64.encode(utf8.encode(str));
}

String decodeBase64Str(String str) {
  return utf8.decode(base64.decode(str));
}
