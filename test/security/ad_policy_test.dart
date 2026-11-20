import 'package:flutter_test/flutter_test.dart';
import 'package:hesabu/core/policy/ad_policy.dart';

void main() {
  test('base HESABU build has no advertising provider or runtime opt-in', () {
    expect(AdPolicy.enabled, isFalse);
    expect(AdPolicy.provider, 'none');
    expect(AdPolicy.allowProvider('any-provider'), isFalse);
  });
}
