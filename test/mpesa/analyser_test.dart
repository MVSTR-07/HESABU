import 'package:hesabu/core/mpesa/analyser.dart';
import 'package:hesabu/core/mpesa/anomaly_rules.dart';
import 'package:hesabu/core/mpesa/models.dart';
import 'package:hesabu/core/sample_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'classifier_test.dart' show fixtureTx;

void main() {
  const analyser = MpesaAnalyser();
  const rules = MpesaAnomalyRules();
  test('exact duplicate rule excludes only the repeated row', () {
    final a = fixtureTx(1, 10000);
    final b = MpesaTransaction(
      row: 2,
      at: a.at,
      receipt: a.receipt,
      details: a.details,
      paidIn: a.paidIn,
      withdrawn: 0,
      balance: a.balance,
    );
    final result = analyser.analyse([a, b]);
    expect(result.moneyIn, 10000);
    expect(result.duplicateRows, {2});
    expect(result.anomalies.single.kind, AnomalyKind.duplicate);
  });
  test(
    'same receipt with a separate fee is retained and flagged for review',
    () {
      final result = analyser.analyse([
        fixtureTx(1, 10000, receipt: 'SHARED0001'),
        fixtureTx(
          2,
          1300,
          receipt: 'SHARED0001',
          details: 'Transaction charge',
          outgoing: true,
        ),
      ]);
      expect(result.uniqueCount, 2);
      expect(result.fees, 1300);
      expect(result.anomalies.single.kind, AnomalyKind.receiptConflict);
    },
  );
  test('spike rule compares against other payments in the same direction', () {
    final txs = [
      for (var i = 1; i <= 3; i++) fixtureTx(i, 10000),
      fixtureTx(4, 100000),
    ];
    final result = rules.scan(txs, const AnomalyThresholds());
    expect(
      result.flags.where((v) => v.kind == AnomalyKind.spike).single.row,
      4,
    );
  });
  test('spike rule requires a baseline and minimum absolute amount', () {
    expect(
      rules
          .scan([fixtureTx(1, 99999999)], const AnomalyThresholds())
          .flags
          .where((v) => v.kind == AnomalyKind.spike),
      isEmpty,
    );
    final tiny = [
      for (var i = 1; i <= 3; i++) fixtureTx(i, 1),
      fixtureTx(4, 1000),
    ];
    expect(rules.scan(tiny, const AnomalyThresholds()).flags, isEmpty);
  });
  test('large one-off rule includes exact threshold and is adjustable', () {
    final tx = fixtureTx(1, 10000000);
    expect(
      rules.scan([tx], const AnomalyThresholds()).flags.single.kind,
      AnomalyKind.largeOneOff,
    );
    expect(
      rules.scan([tx], const AnomalyThresholds(largeAmount: 10000001)).flags,
      isEmpty,
    );
  });
  test('invalid and non-finite thresholds are rejected', () {
    for (final settings in [
      const AnomalyThresholds(largeAmount: 0),
      const AnomalyThresholds(spikeMultiplier: double.nan),
      const AnomalyThresholds(spikeMultiplier: 1),
      const AnomalyThresholds(minimumBaseline: 2),
    ]) {
      expect(
        () => rules.scan([], settings),
        throwsA(isA<StatementImportException>()),
      );
    }
  });
  test(
    'fabricated ledger totals, fees, Fuliza, reversal, rankings and periods',
    () {
      final r = analyser.analyse(generateSampleMpesaTransactions());
      expect(r.moneyIn, 26621000);
      expect(r.moneyOut, 1992700);
      expect(r.net, 24628300);
      expect(r.fees, 12700);
      expect(r.fulizaCost, 7000);
      expect(r.uniqueCount, 22);
      expect(r.duplicateRows.length, 1);
      expect(r.balances.last.balance, 26628300);
      expect(r.senders.first.name, contains('Fatuma Ali'));
      expect(r.receivers.first.name, contains('Ndovu Wholesalers'));
      expect(r.hours[10], 6);
      expect(r.weekdays[3], 6);
      expect(r.hours.reduce((a, b) => a + b), 22);
      for (final periods in [r.daily, r.weekly, r.monthly]) {
        expect(periods.fold(0, (int a, v) => a + v.net), r.net);
      }
      expect(r.weekly.first.key, '2025-12-29');
      expect(
        r.anomalies.map((v) => v.kind).toSet(),
        containsAll([
          AnomalyKind.duplicate,
          AnomalyKind.spike,
          AnomalyKind.largeOneOff,
        ]),
      );
      expect(MpesaResults.fromJson(r.toJson()).moneyIn, r.moneyIn);
    },
  );
  test('higher thresholds remove size/spike flags but not duplicates', () {
    final r = analyser.analyse(
      generateSampleMpesaTransactions(),
      thresholds: const AnomalyThresholds(
        largeAmount: 1000000000,
        spikeMultiplier: 2001,
      ),
    );
    expect(r.anomalies.single.kind, AnomalyKind.duplicate);
  });
}
