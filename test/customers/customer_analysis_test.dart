import 'package:bizlens/core/customers/customer_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

CustomerPayment p(
  String id,
  int day, {
  String customer = 'a',
  int amount = 10000,
  int month = 1,
}) => CustomerPayment(
  id: id,
  identity: customer,
  name: 'Fabricated $customer',
  at: DateTime.utc(2026, month, day, 9),
  amount: amount,
);
void main() {
  test(
    'median uses distinct Kenya purchase dates and resists long outliers',
    () {
      expect(
        medianGap([DateTime.utc(2026, 1, 1), DateTime.utc(2026, 1, 1, 5)]),
        isNull,
      );
      expect(
        medianGap([
          for (final d in [1, 8, 15, 29]) DateTime.utc(2026, 1, d),
        ]),
        7,
      );
      expect(
        medianGap([
          for (final d in [1, 8, 22]) DateTime.utc(2026, 1, d),
        ]),
        10.5,
      );
    },
  );
  test('personal drop-off uses strict > at exact default boundaries', () {
    const config = DropOffConfig();
    expect(dropOff(15, 10, config), isNull);
    expect(dropOff(16, 10, config), CustomerSegment.atRisk);
    expect(dropOff(30, 10, config), CustomerSegment.atRisk);
    expect(dropOff(31, 10, config), CustomerSegment.lost);
    expect(dropOff(500, null, config), isNull);
    expect(dropOff(25, 10, const DropOffConfig(atRisk: 3, lost: 5)), isNull);
    expect(
      () => dropOff(5, 10, const DropOffConfig(atRisk: 3, lost: 2)),
      throwsFormatException,
    );
  });
  test('per-customer baseline differs and sample exercises every segment', () {
    final date = DateTime.utc(2026, 10, 27, 12);
    final result = const CustomerAnalyser().analyse(
      generateCustomerSamples(date),
      asOf: date,
    );
    expect(
      result.customers.map((c) => c.segment).toSet(),
      CustomerSegment.values.toSet(),
    );
    expect(result.customers.first.name, 'Wanjiku Demo');
    expect(
      result.dropped.map((c) => c.name),
      containsAll(['Otieno Demo', 'Fatuma Demo']),
    );
    expect(result.topFiveShare, lessThan(1));
    expect(
      result.customers.every(
        (c) => [c.r, c.f, c.m].every((s) => s >= 1 && s <= 5),
      ),
      isTrue,
    );
  });
  test(
    'totals, first/last, averages, unique payments and future exclusion',
    () {
      final result = const CustomerAnalyser().analyse([
        p('1', 1),
        p('2', 11, amount: 30000),
        p('2', 11, amount: 30000),
        p('3', 25),
      ], asOf: DateTime.utc(2026, 1, 20));
      final c = result.customers.single;
      expect(c.total, 40000);
      expect(c.count, 2);
      expect(c.average, 20000);
      expect(c.gap, 10);
      expect(c.daysSince, 9);
      expect(c.first, p('1', 1).at);
      expect(c.last, p('2', 11).at);
      expect(result.futureExcluded, 1);
    },
  );
  test('manual merges recompute median, ranking and retention without editing payments', () {
    final payments = [
      p('1', 1, customer: 'a'),
      p('2', 11, customer: 'b'),
      p('3', 21, customer: 'a'),
    ];
    final result = const CustomerAnalyser().analyse(
      payments,
      asOf: DateTime.utc(2026, 1, 31),
      aliases: {'b': 'a'},
    );
    expect(result.customers.single.count, 3);
    expect(result.customers.single.gap, 10);
    expect(payments[1].identity, 'b');
    expect(
      () => resolveCustomer('a', {'a': 'b', 'b': 'a'}),
      throwsFormatException,
    );
  });
  test('monthly activity retention and churn include empty months', () {
    final result = const CustomerAnalyser().analyse([
      p('1', 1, customer: 'a'),
      p('2', 1, customer: 'b'),
      p('3', 1, month: 2, customer: 'a'),
      p('4', 1, month: 2, customer: 'c'),
    ], asOf: DateTime.utc(2026, 3, 31));
    expect(result.months.length, 3);
    expect(result.months[0].retention, isNull);
    expect(result.months[1].retention, .5);
    expect(result.months[1].churn, .5);
    expect(result.months[1].newCustomers, 1);
    expect(result.months[2].active, 0);
    expect(result.months[2].churn, 1);
  });
  test('phone normalisation, masked fallback and contact URIs', () {
    expect(kenyaPhone('0700 000 001'), '+254700000001');
    expect(kenyaPhone('254100000001'), '+254100000001');
    expect(kenyaPhone('0700***001'), isNull);
    expect(identityFor(' Amina  Demo ', null), 'name:amina demo');
    final sms = customerContactUri(
      '0700000001',
      message: 'Hello Amina & karibu',
    );
    expect(sms.scheme, 'sms');
    expect(sms.path, '+254700000001');
    expect(sms.queryParameters['body'], 'Hello Amina & karibu');
    expect(sms.toString(), isNot(contains('+karibu')));
    expect(customerContactUri('0700000001').scheme, 'tel');
    expect(() => customerContactUri('07***'), throwsFormatException);
  });
}
