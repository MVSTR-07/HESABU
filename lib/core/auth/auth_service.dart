import 'dart:convert';

/// The only account fields HESABU is allowed to persist are an identifier and
/// entitlement metadata. Passwords and provider tokens never belong in the
/// business database.
abstract interface class AuthService {
  Future<AuthIdentity> signIn(String identifier);
  Future<AuthIdentity> createAccount(String identifier);
  Future<void> signOut();
  Future<void> deleteAccount();
}

class AuthIdentity {
  const AuthIdentity({required this.id, required this.email});
  final String id;
  final String email;

  Map<String, String> toSafeJson() => {'id': id, 'email': email};
}

/// Development-only provider. It deliberately accepts an email only and never
/// creates, receives, hashes, logs or stores a password.
class DemoAuthService implements AuthService {
  DemoAuthService({
    required this.read,
    required this.write,
    required this.remove,
  });

  final String? Function(String key) read;
  final void Function(String key, String value) write;
  final void Function(String key) remove;

  static const emailKey = 'account_email';
  static const signedInKey = 'signed_in';

  @override
  Future<AuthIdentity> signIn(String identifier) async {
    final email = _validateEmail(identifier);
    if (read(emailKey) != email) {
      throw const FormatException(
        'No demo profile matches this email on this device. Use Sign up.',
      );
    }
    write(signedInKey, 'true');
    return AuthIdentity(id: _idFor(email), email: email);
  }

  @override
  Future<AuthIdentity> createAccount(String identifier) async {
    final email = _validateEmail(identifier);
    final existing = read(emailKey);
    if (existing != null && existing != email) {
      throw const FormatException(
        'This device already has a demo profile. Use that email or delete local data.',
      );
    }
    write(emailKey, email);
    write(signedInKey, 'true');
    return AuthIdentity(id: _idFor(email), email: email);
  }

  @override
  Future<void> signOut() async => write(signedInKey, 'false');

  @override
  Future<void> deleteAccount() async {
    remove(emailKey);
    remove(signedInKey);
  }

  static String _validateEmail(String value) {
    final email = value.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      throw const FormatException('Enter a valid email address.');
    }
    return email;
  }

  static String _idFor(String email) =>
      base64Url.encode(utf8.encode(email)).replaceAll('=', '').toLowerCase();
}
