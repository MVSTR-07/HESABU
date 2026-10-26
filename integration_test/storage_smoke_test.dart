import 'package:bizlens/data/device_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real device secure vault and encrypted database can reopen', (
    tester,
  ) async {
    // Uses the real app directory. Run only on a development profile/device.
    var store = await DeviceStore.open();
    store.writeSetting('integration_probe', 'fabricated');
    store.close();
    store = await DeviceStore.open();
    expect(store.readSetting('integration_probe'), 'fabricated');
    store.writeSetting('integration_probe', '');
    store.close();
  });
}
