import 'package:flutter_test/flutter_test.dart';
import 'package:hesabu/data/account_security.dart';

void main() {
  const security = AccountSecurity();

  test('verifier accepts only the original password and never equals it', () {
    final verifier = security.createVerifier('correct horse battery staple');
    expect(verifier, isNot(contains('correct horse')));
    expect(security.verify(verifier, 'correct horse battery staple'), isTrue);
    expect(security.verify(verifier, 'wrong password'), isFalse);
  });

  test('short passwords are rejected', () {
    expect(() => security.createVerifier('short'), throwsFormatException);
  });
}
