import 'package:flutter_test/flutter_test.dart';
import 'package:hesabu/core/auth/auth_service.dart';
import 'package:hesabu/core/subscription/entitlement_service.dart';

void main() {
  test(
    'demo authentication stores identity state but never a password',
    () async {
      final values = <String, String>{};
      final auth = DemoAuthService(
        read: (key) => values[key],
        write: (key, value) => values[key] = value,
        remove: values.remove,
      );
      await auth.createAccount('shop@example.test');
      expect(values['account_email'], 'shop@example.test');
      expect(values.containsKey('password'), isFalse);
      expect(values.containsKey('password_hash'), isFalse);
      await auth.signOut();
      expect(values['signed_in'], 'false');
      await auth.deleteAccount();
      expect(values, isEmpty);
    },
  );

  test('demo entitlement is local preview state only', () async {
    final entitlement = DemoEntitlementService(
      (key) => key == 'demo_paid' ? 'true' : null,
    );
    expect((await entitlement.refresh()).isPremium, isTrue);
  });
}
