import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Local account protection for workspace administration. This is deliberately
/// not server authentication: only a salted verifier is persisted locally.
class AccountSecurity {
  const AccountSecurity();

  String createVerifier(String password) {
    _validate(password);
    final salt = Uint8List.fromList(
      List<int>.generate(16, (_) => Random.secure().nextInt(256)),
    );
    final digest = _digest(salt, password);
    return jsonEncode({'salt': base64UrlEncode(salt), 'digest': digest});
  }

  bool verify(String encoded, String password) {
    try {
      final value = jsonDecode(encoded) as Map<String, dynamic>;
      final salt = base64Url.decode(value['salt'] as String);
      final expected = value['digest'] as String;
      return _digest(Uint8List.fromList(salt), password) == expected;
    } on Object {
      return false;
    }
  }

  static void _validate(String password) {
    if (password.length < 8) {
      throw const FormatException('Password must be at least 8 characters.');
    }
  }

  static String _digest(List<int> salt, String password) => sha256
      .convert([...salt, ...utf8.encode(password)])
      .toString();
}
